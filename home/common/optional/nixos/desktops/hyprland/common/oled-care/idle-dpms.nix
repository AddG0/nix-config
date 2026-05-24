{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.oledCare.idleDpms;

  no-sleep = pkgs.writeShellApplication {
    name = "no-sleep";
    runtimeInputs = with pkgs; [systemd coreutils];
    text = builtins.readFile ./no-sleep.sh;
  };
in {
  config = lib.mkIf cfg.enable {
    home.packages = [no-sleep];

    services.hypridle.settings.listener = [
      {
        timeout = 180;
        on-timeout = "loginctl lock-session";
      }
      {
        timeout = 240;
        on-timeout = "hyprctl dispatch dpms off";
        on-resume = "hyprctl dispatch dpms on";
      }
    ];
  };
}
