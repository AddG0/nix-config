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
          # Hold systemd-logind's sleep inhibitor until the lock-screen client
          # signals `hyprland-lock-notify-v1` (i.e. hyprlock's surface is
          # actually mapped). Default mode 2 ("auto") releases the inhibitor
          # before hyprlock finishes its dmabuf screencopy + fadeIn, the
          # InhibitDelayMaxSec=5s ceiling fires, and the system suspends
          # mid-render — hyprlock logs "Seems we got yeeten" on wake and the
          # lock screen comes back garbled.
          #   Wiki:        https://wiki.hypr.land/Hypr-Ecosystem/hypridle/
          #   Root cause:  https://github.com/hyprwm/hypridle/issues/146
          #   Symptom:     https://github.com/hyprwm/Hyprland/issues/5913
          inhibit_sleep = 3;
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
