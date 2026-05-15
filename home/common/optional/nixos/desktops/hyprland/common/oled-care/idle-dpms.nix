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

    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          # SIGUSR1 is hyprlock's documented graceful-unlock signal (PR
          # hyprwm/hyprlock#756, v0.8.2+) — same code path as a correct
          # password. Lets `loginctl unlock-session` actually dismiss the lock.
          unlock_cmd = "${pkgs.procps}/bin/pkill -USR1 hyprlock";
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
