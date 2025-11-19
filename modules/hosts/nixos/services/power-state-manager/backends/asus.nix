# ASUS laptop hardware backend (asusctl)
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.powerStateManager;
in {
  options.services.powerStateManager.asus = {
    enable = mkEnableOption "ASUS laptop hardware backend (asusctl)";

    onBattery.profile = mkOption {
      type = types.nullOr (types.enum ["Quiet" "Balanced" "Performance"]);
      default = null;
      description = "ASUS performance profile on battery. Requires ASUS backend.";
    };

    onAC.profile = mkOption {
      type = types.nullOr (types.enum ["Quiet" "Balanced" "Performance"]);
      default = null;
      description = "ASUS performance profile on AC. Requires ASUS backend.";
    };
  };

  config = mkIf (cfg.enable && cfg.asus.enable) {
    # Contribute to system battery script (runs in parallel with other backends)
    services.powerStateManager._internal.systemBatteryFragments = mkIf (cfg.asus.onBattery.profile != null) {
      "asus" = ''
        # ASUS: Set profile to ${cfg.asus.onBattery.profile}
        ${pkgs.asusctl}/bin/asusctl profile -P ${cfg.asus.onBattery.profile}
      '';
    };

    # Contribute to system AC script (runs in parallel with other backends)
    services.powerStateManager._internal.systemACFragments = mkIf (cfg.asus.onAC.profile != null) {
      "asus" = ''
        # ASUS: Set profile to ${cfg.asus.onAC.profile}
        ${pkgs.asusctl}/bin/asusctl profile -P ${cfg.asus.onAC.profile}
      '';
    };

    # Contribute startup dependencies
    services.powerStateManager._internal.startupDependencies = ["asusd.service"];

    # Validation
    assertions = [
      {
        assertion = cfg.asus.onBattery.profile != null -> cfg.asus.onAC.profile != null;
        message = "If asus.onBattery.profile is set, asus.onAC.profile should also be set";
      }
    ];

    # Warnings
    warnings =
      optional (!config.services.asusd.enable)
      "powerStateManager.asus.enable is true but services.asusd is not enabled";
  };
}
