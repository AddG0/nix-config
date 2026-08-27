// SPDX-License-Identifier: GPL-2.0
/*
 * Razer Blade charge cap (Battery Health Optimizer) as a power_supply charge_types.
 *
 * The cap lives in the EC behind a vendor HID report, so no kernel driver owns
 * it and UPower sees a battery with no charge-threshold support. Long_Life maps
 * to cap on, Standard to cap off.
 *
 * Protocol reverse-engineered by tdakhran/razer-ctl (librazer).
 */

#include <linux/bits.h>
#include <linux/build_bug.h>
#include <linux/hid.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/power_supply.h>
#include <linux/usb.h>
#include <linux/workqueue.h>

#define RAZER_VENDOR_ID 0x1532
#define RAZER_BLADE_2026_PID 0x02e0

/*
 * Interface 3 looks like the control path (it carries vendor usage page 0xff00)
 * but is a decoy: it acknowledges writes with status "successful" and a correct
 * echo, discards them, and reads back a value that never tracks reality.
 */
#define RAZER_DEFAULT_CONTROL_INTERFACE 0

#define RAZER_REPORT_SIZE 90
/* usbhid skips a leading byte when the report id is 0. */
#define RAZER_BUFFER_SIZE (RAZER_REPORT_SIZE + 1)

#define RAZER_STATUS_NEW 0x00
#define RAZER_STATUS_OK 0x02
#define RAZER_STATUS_UNSUPPORTED 0x05

#define RAZER_CLASS_POWER 0x07
#define RAZER_ID_SET_BATTERY_CARE 0x12
#define RAZER_ID_GET_BATTERY_CARE 0x92

/* High bit enables the cap; the low bits carry the percentage. */
#define RAZER_BHO_ENABLE BIT(7)

static char *battery = "BAT0";
module_param(battery, charp, 0444);
MODULE_PARM_DESC(battery, "power_supply name to extend (default: BAT0)");

static unsigned int control_interface = RAZER_DEFAULT_CONTROL_INTERFACE;
module_param(control_interface, uint, 0444);
MODULE_PARM_DESC(control_interface,
		 "USB interface the EC accepts commands on (default 0)");

static unsigned int threshold = 80;
module_param(threshold, uint, 0444);
MODULE_PARM_DESC(threshold,
		 "charge cap percentage (50-80, default 80; only 80 is verified on hardware)");

struct razer_report {
	u8 status;
	u8 transaction_id;
	__be16 remaining_packets;
	u8 protocol_type;
	u8 data_size;
	u8 command_class;
	u8 command_id;
	u8 args[80];
	u8 crc;
	u8 reserved;
} __packed;

static_assert(sizeof(struct razer_report) == RAZER_REPORT_SIZE);

struct razer_bho {
	struct hid_device *hdev;
	struct power_supply *psy;
	/* Serialises the set-then-read round trip against the EC. */
	struct mutex lock;
	u8 transaction_id;
	/* Cached: power_supply_changed() makes userspace re-read every property,
	 * and each EC round trip costs ~3ms. */
	bool cap_enabled;
	struct delayed_work attach_work;
	unsigned int attach_attempts;
};

/* XOR over bytes [2,88): skips status/transaction_id and the trailing crc. */
static u8 razer_crc(const struct razer_report *report)
{
	const u8 *bytes = (const u8 *)report;
	u8 crc = 0;
	unsigned int i;

	for (i = 2; i < 88; i++)
		crc ^= bytes[i];

	return crc;
}

/*
 * One request/response round trip; @response_arg receives args[0] of the reply.
 * Caller holds drv->lock.
 */
static int razer_transact(struct razer_bho *drv, u8 command_class, u8 command_id,
			  const u8 *args, size_t num_args, u8 *response_arg)
{
	struct razer_report *report;
	u8 expected_transaction;
	u8 *buffer;
	int ret;

	if (num_args > sizeof(report->args))
		return -EINVAL;

	buffer = kzalloc(RAZER_BUFFER_SIZE, GFP_KERNEL);
	if (!buffer)
		return -ENOMEM;

	report = (struct razer_report *)(buffer + 1);
	expected_transaction = ++drv->transaction_id;

	report->status = RAZER_STATUS_NEW;
	report->transaction_id = expected_transaction;
	report->data_size = num_args;
	report->command_class = command_class;
	report->command_id = command_id;
	memcpy(report->args, args, num_args);
	report->crc = razer_crc(report);

	/* The EC drops reports that arrive back to back. */
	usleep_range(1000, 1500);

	ret = hid_hw_raw_request(drv->hdev, 0x00, buffer, RAZER_BUFFER_SIZE,
				 HID_FEATURE_REPORT, HID_REQ_SET_REPORT);
	if (ret != RAZER_BUFFER_SIZE) {
		hid_err(drv->hdev, "set_report %02x%02x failed: %d\n",
			command_class, command_id, ret);
		ret = ret < 0 ? ret : -EIO;
		goto out;
	}

	usleep_range(2000, 2500);

	memset(buffer, 0, RAZER_BUFFER_SIZE);
	ret = hid_hw_raw_request(drv->hdev, 0x00, buffer, RAZER_BUFFER_SIZE,
				 HID_FEATURE_REPORT, HID_REQ_GET_REPORT);
	if (ret != RAZER_BUFFER_SIZE) {
		hid_err(drv->hdev, "get_report %02x%02x failed: %d\n",
			command_class, command_id, ret);
		ret = ret < 0 ? ret : -EIO;
		goto out;
	}

	/* remaining_packets is left out: BHO replies carry a value that differs
	 * from the request (librazer exempts 0x0792 the same way). */
	if (report->transaction_id != expected_transaction ||
	    report->command_class != command_class ||
	    report->command_id != command_id) {
		hid_err(drv->hdev, "response does not match request\n");
		ret = -EIO;
		goto out;
	}

	if (report->status == RAZER_STATUS_UNSUPPORTED) {
		hid_err(drv->hdev, "command %02x%02x not supported by this EC\n",
			command_class, command_id);
		ret = -EOPNOTSUPP;
		goto out;
	}

	if (report->status != RAZER_STATUS_OK) {
		hid_err(drv->hdev, "command %02x%02x returned status %02x\n",
			command_class, command_id, report->status);
		ret = -EIO;
		goto out;
	}

	if (response_arg)
		*response_arg = report->args[0];

	ret = 0;

out:
	kfree(buffer);
	return ret;
}

static int razer_bho_read(struct razer_bho *drv, bool *enabled)
{
	static const u8 args[1] = { 0x00 };
	u8 value = 0;
	int ret;

	ret = razer_transact(drv, RAZER_CLASS_POWER, RAZER_ID_GET_BATTERY_CARE,
			     args, sizeof(args), &value);
	if (ret)
		return ret;

	*enabled = !!(value & RAZER_BHO_ENABLE);
	return 0;
}

/* BAT0 registers a few hundred ms after USB enumeration, so it is usually still
 * missing at probe; retry rather than give up on the charge cap. */
#define RAZER_ATTACH_RETRY_MS 500
#define RAZER_ATTACH_MAX_ATTEMPTS 40

/* Bound on how long the EC may take to adopt a write. */
#define RAZER_VERIFY_ATTEMPTS 5
#define RAZER_VERIFY_DELAY_US 100000

static int razer_bho_write(struct razer_bho *drv, bool enable)
{
	u8 args[1] = { enable ? (RAZER_BHO_ENABLE | threshold) : threshold };
	u8 echoed = 0;
	unsigned int attempt;
	int ret;

	ret = razer_transact(drv, RAZER_CLASS_POWER, RAZER_ID_SET_BATTERY_CARE,
			     args, sizeof(args), &echoed);
	if (ret)
		return ret;

	if (echoed != args[0]) {
		hid_err(drv->hdev, "set battery care echoed %02x, wanted %02x\n",
			echoed, args[0]);
		return -EIO;
	}

	/* The echo proves the EC parsed the command, not that it kept it: a
	 * silently dropped write must fail rather than show a cap that is off. */
	for (attempt = 0; attempt < RAZER_VERIFY_ATTEMPTS; attempt++) {
		bool actual;

		usleep_range(RAZER_VERIFY_DELAY_US, RAZER_VERIFY_DELAY_US + 10000);

		ret = razer_bho_read(drv, &actual);
		if (ret)
			return ret;

		if (actual == enable) {
			hid_info(drv->hdev, "battery care %s, confirmed after %ums\n",
				 enable ? "enabled" : "disabled",
				 (attempt + 1) * (RAZER_VERIFY_DELAY_US / 1000));
			return 0;
		}

		hid_dbg(drv->hdev, "attempt %u: wrote %02x, EC still reports %s\n",
			attempt + 1, args[0], actual ? "enabled" : "disabled");
	}

	hid_err(drv->hdev, "EC acknowledged %02x but did not adopt it\n", args[0]);
	return -EIO;
}

static const enum power_supply_property razer_bho_properties[] = {
	POWER_SUPPLY_PROP_CHARGE_TYPES,
};

static int razer_bho_get_property(struct power_supply *psy,
				  const struct power_supply_ext *ext, void *data,
				  enum power_supply_property psp,
				  union power_supply_propval *val)
{
	struct razer_bho *drv = data;

	if (psp != POWER_SUPPLY_PROP_CHARGE_TYPES)
		return -EINVAL;

	val->intval = READ_ONCE(drv->cap_enabled) ?
			      POWER_SUPPLY_CHARGE_TYPE_LONGLIFE :
			      POWER_SUPPLY_CHARGE_TYPE_STANDARD;
	return 0;
}

static int razer_bho_set_property(struct power_supply *psy,
				  const struct power_supply_ext *ext, void *data,
				  enum power_supply_property psp,
				  const union power_supply_propval *val)
{
	struct razer_bho *drv = data;
	bool enable;
	int ret;

	if (psp != POWER_SUPPLY_PROP_CHARGE_TYPES)
		return -EINVAL;

	switch (val->intval) {
	case POWER_SUPPLY_CHARGE_TYPE_LONGLIFE:
		enable = true;
		break;
	case POWER_SUPPLY_CHARGE_TYPE_STANDARD:
		enable = false;
		break;
	default:
		return -EINVAL;
	}

	guard(mutex)(&drv->lock);

	ret = razer_bho_write(drv, enable);
	if (ret)
		return ret;

	WRITE_ONCE(drv->cap_enabled, enable);
	return 0;
}

static int razer_bho_property_is_writeable(struct power_supply *psy,
					   const struct power_supply_ext *ext,
					   void *data,
					   enum power_supply_property psp)
{
	return psp == POWER_SUPPLY_PROP_CHARGE_TYPES;
}

static const struct power_supply_ext razer_bho_ext = {
	.name = "razer_battery_care",
	/* UPower infers support from Long_Life next to a normal charging mode. */
	.charge_types = BIT(POWER_SUPPLY_CHARGE_TYPE_STANDARD) |
			BIT(POWER_SUPPLY_CHARGE_TYPE_LONGLIFE),
	.properties = razer_bho_properties,
	.num_properties = ARRAY_SIZE(razer_bho_properties),
	.get_property = razer_bho_get_property,
	.set_property = razer_bho_set_property,
	.property_is_writeable = razer_bho_property_is_writeable,
};

/*
 * A failure here costs the charge cap and nothing else. Escalating it would
 * mean unbinding the interface, which on interface 0 takes the keyboard too.
 */
static void razer_bho_attach(struct work_struct *work)
{
	struct razer_bho *drv = container_of(to_delayed_work(work),
					     struct razer_bho, attach_work);
	struct hid_device *hdev = drv->hdev;
	int ret;

	drv->psy = power_supply_get_by_name(battery);
	if (!drv->psy) {
		if (++drv->attach_attempts < RAZER_ATTACH_MAX_ATTEMPTS) {
			schedule_delayed_work(&drv->attach_work,
					      msecs_to_jiffies(RAZER_ATTACH_RETRY_MS));
			return;
		}
		hid_err(hdev, "no power supply named '%s'\n", battery);
		return;
	}

	scoped_guard(mutex, &drv->lock) {
		ret = razer_bho_read(drv, &drv->cap_enabled);
	}
	if (ret) {
		hid_err(hdev, "EC did not report battery care state: %d\n", ret);
		goto put_psy;
	}

	ret = power_supply_register_extension(drv->psy, &razer_bho_ext,
					      &hdev->dev, drv);
	if (ret) {
		/* -EEXIST means something already owns charge_types on this battery. */
		hid_err(hdev, "could not extend '%s': %d\n", battery, ret);
		goto put_psy;
	}

	hid_info(hdev, "battery care %s, cap %u%%, charge_types on '%s'\n",
		 drv->cap_enabled ? "enabled" : "disabled", threshold, battery);
	return;

put_psy:
	power_supply_put(drv->psy);
	drv->psy = NULL;
}

static int razer_bho_probe(struct hid_device *hdev,
			   const struct hid_device_id *id)
{
	struct usb_interface *intf;
	struct razer_bho *drv;
	int ret;

	if (!hid_is_usb(hdev))
		return -ENODEV;

	drv = devm_kzalloc(&hdev->dev, sizeof(*drv), GFP_KERNEL);
	if (!drv)
		return -ENOMEM;

	drv->hdev = hdev;
	ret = devm_mutex_init(&hdev->dev, &drv->lock);
	if (ret)
		return ret;
	/* Initialised on every interface so remove() can cancel unconditionally. */
	INIT_DELAYED_WORK(&drv->attach_work, razer_bho_attach);
	hid_set_drvdata(hdev, drv);

	/* Mirrors hid_generic_probe(), so input devices come out identical. */
	hdev->quirks |= HID_QUIRK_INPUT_PER_APP;

	ret = hid_parse(hdev);
	if (ret)
		return ret;

	ret = hid_hw_start(hdev, HID_CONNECT_DEFAULT);
	if (ret)
		return ret;

	/* Every interface is claimed, not just this one: hid-generic stands aside
	 * for any driver whose id_table matches and a HID id cannot name a USB
	 * interface, so anything declined here ends up with no driver at all. */
	intf = to_usb_interface(hdev->dev.parent);
	if (intf->cur_altsetting->desc.bInterfaceNumber != control_interface)
		return 0;

	schedule_delayed_work(&drv->attach_work, 0);
	return 0;
}

static void razer_bho_remove(struct hid_device *hdev)
{
	struct razer_bho *drv = hid_get_drvdata(hdev);

	cancel_delayed_work_sync(&drv->attach_work);
	if (drv->psy) {
		power_supply_unregister_extension(drv->psy, &razer_bho_ext);
		power_supply_put(drv->psy);
	}
	hid_hw_stop(hdev);
}

/* The EC's behaviour across suspend is undocumented, so check rather than trust. */
static int razer_bho_resume(struct hid_device *hdev)
{
	struct razer_bho *drv = hid_get_drvdata(hdev);
	bool actual;
	int ret;

	if (!drv->psy)
		return 0;

	guard(mutex)(&drv->lock);

	ret = razer_bho_read(drv, &actual);
	if (ret) {
		hid_warn(hdev, "could not read battery care on resume: %d\n", ret);
		return 0;
	}

	if (actual == drv->cap_enabled)
		return 0;

	hid_info(hdev, "battery care lost across suspend, restoring\n");
	ret = razer_bho_write(drv, drv->cap_enabled);
	if (ret)
		hid_warn(hdev, "could not restore battery care: %d\n", ret);

	return 0;
}

static const struct hid_device_id razer_bho_devices[] = {
	{ HID_USB_DEVICE(RAZER_VENDOR_ID, RAZER_BLADE_2026_PID) },
	{ }
};
MODULE_DEVICE_TABLE(hid, razer_bho_devices);

static struct hid_driver razer_bho_driver = {
	.name = "razer-battery-care",
	.id_table = razer_bho_devices,
	.probe = razer_bho_probe,
	.remove = razer_bho_remove,
#ifdef CONFIG_PM
	.resume = razer_bho_resume,
	.reset_resume = razer_bho_resume,
#endif
};
static int __init razer_bho_init(void)
{
	if (threshold < 50 || threshold > 80) {
		pr_err("razer-battery-care: threshold %u out of range (50-80)\n",
		       threshold);
		return -EINVAL;
	}

	return hid_register_driver(&razer_bho_driver);
}

static void __exit razer_bho_exit(void)
{
	hid_unregister_driver(&razer_bho_driver);
}

module_init(razer_bho_init);
module_exit(razer_bho_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("addg");
MODULE_DESCRIPTION("Razer Blade Battery Health Optimizer via power_supply charge_types");
