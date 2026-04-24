{
  lib,
  pkgs,
  config,
  ...
}: let
  oledMonitorNames = map (m: m.name) (lib.filter (m: m.oled) config.monitors);

  no-sleep = pkgs.writeShellApplication {
    name = "no-sleep";
    runtimeInputs = with pkgs; [systemd coreutils];
    text = builtins.readFile ./no-sleep.sh;
  };
in {
  config = lib.mkIf (oledMonitorNames != []) {
    home.packages = [no-sleep];

    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };

        listener = [
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
    };
  };
}
