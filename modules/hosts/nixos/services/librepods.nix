{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.librepods;
in {
  options.programs.librepods = {
    enable = mkEnableOption "LibrePods - AirPods integration for Linux";

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically start LibrePods on login";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.librepods;
      description = "LibrePods package to use";
    };
  };

  config = mkIf cfg.enable {
    # Ensure bluetooth is enabled
    hardware.bluetooth.enable = mkDefault true;

    # Ensure LibrePods is installed
    environment.systemPackages = [ cfg.package ];

    # Create systemd user service to auto-start LibrePods if enabled
    systemd.user.services.librepods = mkIf cfg.autoStart {
      description = "LibrePods - AirPods integration for Linux";
      after = ["bluetooth.target" "pipewire.service"];
      wants = ["bluetooth.target"];
      wantedBy = ["default.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/librepods --hide";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
