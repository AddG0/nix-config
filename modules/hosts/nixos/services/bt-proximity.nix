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

    device = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Bluetooth device MAC address to monitor (e.g., AA:BB:CC:DD:EE:FF). Use deviceFile instead for secrets.";
      example = "AA:BB:CC:DD:EE:FF";
    };

    deviceFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing Bluetooth device MAC address (e.g., sops secret path)";
      example = literalExpression "config.sops.secrets.bt-device-mac.path";
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
    # Validate that exactly one of device or deviceFile is set
    assertions = [
      {
        assertion = (cfg.device != null) != (cfg.deviceFile != null);
        message = "Either services.bt-proximity.device or services.bt-proximity.deviceFile must be set (but not both)";
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
      } // (if cfg.deviceFile != null then {
        BT_DEVICE_FILE = cfg.deviceFile;
      } else {
        BT_DEVICE = cfg.device;
      });
    };
  };
}
