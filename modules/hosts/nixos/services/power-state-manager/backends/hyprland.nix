# Hyprland display backend: switches outputs' refresh rate between battery and AC via `hypr-monitor-control rate`.
{
  config,
  lib,
  customPkgs,
  ...
}: let
  cfg = config.services.powerStateManager;
  hyprCfg = cfg.hyprland;

  setAll = rate:
    lib.concatMapStringsSep "\n" (output: "${lib.getExe customPkgs.hypr-monitor-control} rate ${lib.escapeShellArg output} ${toString rate}") hyprCfg.outputs;

  refreshRateOption = power:
    lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Refresh rate (Hz) for the Hyprland outputs on ${power}.";
      example = 60;
    };
in {
  options.services.powerStateManager.hyprland = {
    outputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Hyprland output names whose refresh rate follows the power source.";
      example = ["eDP-1"];
    };
    onBattery.refreshRate = refreshRateOption "battery";
    onAC.refreshRate = refreshRateOption "AC";
  };

  config = lib.mkIf (cfg.enable && hyprCfg.outputs != []) {
    services.powerStateManager._internal = {
      userBatteryFragments.hyprland = setAll hyprCfg.onBattery.refreshRate;
      userACFragments.hyprland = setAll hyprCfg.onAC.refreshRate;
    };

    # Power changes only reach a running session; this applies the state at login.
    systemd.user.services.power-state-manager-user = {
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];
    };

    assertions = [
      {
        assertion = hyprCfg.onBattery.refreshRate != null && hyprCfg.onAC.refreshRate != null;
        message = "services.powerStateManager.hyprland: set both onBattery.refreshRate and onAC.refreshRate when outputs is non-empty, or the other power state never restores the rate.";
      }
    ];
  };
}
