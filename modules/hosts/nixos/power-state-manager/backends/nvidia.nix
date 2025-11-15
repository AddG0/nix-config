# NVIDIA GPU mode switching backend (via supergfxctl)
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.powerStateManager;
in {
  options.services.powerStateManager.nvidia = {
    enable = mkEnableOption "NVIDIA GPU mode switching (via supergfxctl)";

    onBattery.mode = mkOption {
      type = types.nullOr (types.enum ["Integrated" "Hybrid" "AsusMuxDgpu"]);
      default = null;
      description = "GPU mode on battery. Requires reboot to take effect.";
    };

    onAC.mode = mkOption {
      type = types.nullOr (types.enum ["Integrated" "Hybrid" "AsusMuxDgpu"]);
      default = null;
      description = "GPU mode on AC. Requires reboot to take effect.";
    };
  };

  config = mkIf (cfg.enable && cfg.nvidia.enable) {
    # Contribute to system battery script (runs in parallel with other backends)
    services.powerStateManager._internal.systemBatteryFragments = mkIf (cfg.nvidia.onBattery.mode != null) {
      "nvidia" = ''
        # NVIDIA: Set GPU mode to ${cfg.nvidia.onBattery.mode}
        ${pkgs.supergfxctl}/bin/supergfxctl -m ${cfg.nvidia.onBattery.mode}
      '';
    };

    # Contribute to system AC script (runs in parallel with other backends)
    services.powerStateManager._internal.systemACFragments = mkIf (cfg.nvidia.onAC.mode != null) {
      "nvidia" = ''
        # NVIDIA: Set GPU mode to ${cfg.nvidia.onAC.mode}
        ${pkgs.supergfxctl}/bin/supergfxctl -m ${cfg.nvidia.onAC.mode}
      '';
    };

    # Contribute startup dependencies
    services.powerStateManager._internal.startupDependencies = ["supergfxd.service"];

    # Validation
    assertions = [
      {
        assertion = cfg.nvidia.onBattery.mode != null -> cfg.nvidia.onAC.mode != null;
        message = "If nvidia.onBattery.mode is set, nvidia.onAC.mode should also be set";
      }
    ];

    # Warnings
    warnings = optional (!config.services.supergfxd.enable)
      "powerStateManager.nvidia.enable is true but services.supergfxd is not enabled";
  };
}
