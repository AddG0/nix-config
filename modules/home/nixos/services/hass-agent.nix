{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.hassAgent;

  args = lib.concatStringsSep " " (
    lib.optional cfg.terminal "--terminal"
    ++ ["--log-level=${cfg.logLevel}"]
    ++ lib.optional (cfg.appId != null) "--appid=${cfg.appId}"
  );
in {
  options.services.hassAgent = {
    enable = lib.mkEnableOption "Home Assistant agent (go-hass-agent) running as a user service";

    package = lib.mkPackageOption pkgs "go-hass-agent" {};

    terminal = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run without a GUI tray icon. Recommended when running as a daemon,
        since the systray error noise only matters if you want a tray icon.
      '';
    };

    logLevel = lib.mkOption {
      type = lib.types.enum ["trace" "debug" "info" "warn" "error"];
      default = "info";
      description = "Agent log level.";
    };

    appId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the agent's app id (mostly useful for running multiple instances).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    systemd.user.services.hass-agent = {
      Unit = {
        Description = "Home Assistant Agent";
        Wants = ["network-online.target"];
        After = ["network-online.target" "nss-lookup.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe' cfg.package "go-hass-agent-amd64"} ${args} run";
        Restart = "always";
        RestartSec = 30;
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
