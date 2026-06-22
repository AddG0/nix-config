{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.hassAgent;

  args = "--log-level=${cfg.logLevel}";
in {
  options.services.hassAgent = {
    enable = lib.mkEnableOption "Home Assistant agent (go-hass-agent) running as a user service";

    package = lib.mkPackageOption pkgs "go-hass-agent" {};

    logLevel = lib.mkOption {
      type = lib.types.enum ["trace" "debug" "info" "warn" "error"];
      default = "info";
      description = "Agent log level.";
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
        ExecStart = "${lib.getExe cfg.package} ${args} run";
        Restart = "always";
        RestartSec = 30;
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
