#
# Razer Blade 16 (2026) — battery charge cap, surfaced through UPower so that
# noctalia's Control Center renders the toggle with no shell-side config.
#
# Whether the cap is on is deliberately not declared here: the EC keeps it
# across reboots, and UPower owns the preference in /var/lib/upower.
#
# UPower latches charge-threshold support when the battery first appears, so it
# must start after the driver attaches. Measured on freya: driver at ~10s,
# upower at ~59s.
#
{
  config,
  pkgs,
  ...
}: let
  razer-battery-care = config.boot.kernelPackages.callPackage ../../../pkgs/razer-battery-care {};

  # hid-generic claims the Blade first and the HID bus never rebinds on its own;
  # openrazer does the same dance for its devices.
  bind = pkgs.writeShellScript "razer-battery-care-bind" ''
    set -eu
    dev="$1"

    [ -d /sys/bus/hid/drivers/razer-battery-care ] ||
      ${pkgs.kmod}/bin/modprobe razer_battery_care

    if [ -d /sys/bus/hid/drivers/hid-generic/"$dev" ]; then
      printf '%s' "$dev" > /sys/bus/hid/drivers/hid-generic/unbind
    fi

    # Every interface, not just the EC's: hid-generic stands aside for any driver
    # whose id_table matches, so a skipped one is left with no driver at all.
    if [ ! -d /sys/bus/hid/drivers/razer-battery-care/"$dev" ]; then
      printf '%s' "$dev" > /sys/bus/hid/drivers/razer-battery-care/bind
    fi
  '';
in {
  boot.extraModulePackages = [razer-battery-care];
  boot.kernelModules = ["razer_battery_care"];

  # Instance suffixes (…02E0.0001) are allocation-ordered and shift per boot.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hid", ENV{HID_ID}=="0003:00001532:000002E0", RUN+="${bind} $kernel"
  '';

  # UPower guards this behind polkit, whose allow_active default needs a logind
  # session; noctalia runs under user@.service and has none.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.UPower.enable-charging-limit" &&
          subject.isInGroup("users")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Reads the EC directly, for when the driver and the desktop disagree.
  environment.systemPackages = [pkgs.razer-cli];
}
