{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.bt-proximity;
in {
  options.services.bt-proximity = {
    enable = mkEnableOption "Bluetooth proximity-based screen locking";

    deviceMacAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Bluetooth device MAC address to monitor (e.g., AA:BB:CC:DD:EE:FF). Use deviceMacAddressFile instead for secrets.";
      example = "AA:BB:CC:DD:EE:FF";
    };

    deviceMacAddressFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing Bluetooth device MAC address (e.g., sops secret path)";
      example = literalExpression "config.sops.secrets.bt-device-mac.path";
    };

    deviceName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Bluetooth device name to monitor (e.g., 'Add's WHOOP'). Alternative to MAC address.";
      example = "My Device";
    };

    deviceNameFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing Bluetooth device name (e.g., sops secret path)";
      example = literalExpression "config.sops.secrets.bt-device-name.path";
    };

    deviceServiceUuid = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Bluetooth service UUID to monitor (most reliable for BLE). Alternative to MAC address.";
      example = "fd4b0001-cce1-4033-93ce-002d5875f58a";
    };

    deviceServiceUuidFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing Bluetooth service UUID (e.g., sops secret path)";
      example = literalExpression "config.sops.secrets.bt-device-uuid.path";
    };

    lockCommand = mkOption {
      type = types.str;
      default = "${pkgs.systemd}/bin/loginctl lock-session";
      description = "Command to execute when device goes out of range";
    };

    unlockCommand = mkOption {
      type = types.str;
      default = "${pkgs.systemd}/bin/loginctl unlock-session";
      description = "Command to execute when device comes back in range";
    };

    # Timing settings
    proximityTimeout = mkOption {
      type = types.float;
      default = 25.0;
      description = "Grace period in seconds before marking device as 'away'";
    };

    # RSSI thresholds
    lockThreshold = mkOption {
      type = types.int;
      default = -75;
      description = "RSSI threshold in dBm for locking (lock when signal drops below this)";
    };

    unlockThreshold = mkOption {
      type = types.int;
      default = -68;
      description = "RSSI threshold in dBm for unlocking (unlock when signal rises above this)";
    };

    # RSSI averaging
    rssiSamples = mkOption {
      type = types.int;
      default = 2;
      description = "Number of RSSI samples for rolling average (small buffer for devices with slow advertisement intervals)";
    };
  };

  config = mkIf cfg.enable {
    # Validate that at least one identification method is set
    assertions = [
      {
        assertion = (
          cfg.deviceMacAddress != null || cfg.deviceMacAddressFile != null ||
          cfg.deviceName != null || cfg.deviceNameFile != null ||
          cfg.deviceServiceUuid != null || cfg.deviceServiceUuidFile != null
        );
        message = "At least one of services.bt-proximity.{deviceMacAddress, deviceMacAddressFile, deviceName, deviceNameFile, deviceServiceUuid, deviceServiceUuidFile} must be set";
      }
      {
        assertion = !(cfg.deviceMacAddress != null && cfg.deviceMacAddressFile != null);
        message = "services.bt-proximity.deviceMacAddress and services.bt-proximity.deviceMacAddressFile cannot both be set (use one or the other)";
      }
      {
        assertion = !(cfg.deviceName != null && cfg.deviceNameFile != null);
        message = "services.bt-proximity.deviceName and services.bt-proximity.deviceNameFile cannot both be set (use one or the other)";
      }
      {
        assertion = !(cfg.deviceServiceUuid != null && cfg.deviceServiceUuidFile != null);
        message = "services.bt-proximity.deviceServiceUuid and services.bt-proximity.deviceServiceUuidFile cannot both be set (use one or the other)";
      }
    ];

    # Ensure bluetooth is enabled
    hardware.bluetooth.enable = mkDefault true;

    # Create Python script for bt-proximity monitoring
    systemd.user.services.bt-proximity = {
      description = "Bluetooth Proximity Detection for Screen Locking";
      after = ["bluetooth.target"];
      wants = ["bluetooth.target"];
      wantedBy = ["default.target"];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 10;
        ExecStart = "${pkgs.bt-proximity-monitor}/bin/bt-proximity-monitor";
      };

      environment = {
        PYTHONUNBUFFERED = "1";
        BT_LOCK_CMD = cfg.lockCommand;
        BT_UNLOCK_CMD = cfg.unlockCommand;
        BT_PROXIMITY_TIMEOUT = toString cfg.proximityTimeout;
        BT_LOCK_THRESHOLD = toString cfg.lockThreshold;
        BT_UNLOCK_THRESHOLD = toString cfg.unlockThreshold;
        BT_RSSI_SAMPLES = toString cfg.rssiSamples;
      } // (if cfg.deviceMacAddressFile != null then {
        BT_DEVICE_MAC_ADDRESS_FILE = cfg.deviceMacAddressFile;
      } else if cfg.deviceMacAddress != null then {
        BT_DEVICE_MAC_ADDRESS = cfg.deviceMacAddress;
      } else {})
        // (if cfg.deviceNameFile != null then {
        BT_DEVICE_NAME_FILE = cfg.deviceNameFile;
      } else if cfg.deviceName != null then {
        BT_DEVICE_NAME = cfg.deviceName;
      } else {})
        // (if cfg.deviceServiceUuidFile != null then {
        BT_DEVICE_SERVICE_UUID_FILE = cfg.deviceServiceUuidFile;
      } else if cfg.deviceServiceUuid != null then {
        BT_DEVICE_SERVICE_UUID = cfg.deviceServiceUuid;
      } else {});
    };
  };
}
