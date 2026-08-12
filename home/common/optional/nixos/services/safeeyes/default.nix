{
  pkgs,
  lib,
  ...
}: let
  safeeyesConfig = {
    meta.config_version = "6.0.4";

    random_order = false;
    allow_postpone = false;
    strict_break = false;
    persist_state = false;

    short_break_interval = 20;
    short_break_duration = 20;
    pre_break_warning_time = 10;

    long_break_interval = 120;
    long_break_duration = 60;
    long_breaks = [];

    postpone_duration = 5;
    postpone_unit = "minutes";
    shortcut_disable_time = 2;
    shortcut_skip = 9;
    shortcut_postpone = 65;

    short_breaks = [
      {
        name = "Look at something 20 feet away";
      }
    ];

    plugins = [
      {
        id = "notification";
        enabled = true;
        version = "0.0.1";
      }
      {
        id = "audiblealert";
        enabled = true;
        version = "0.0.3";
        settings = {
          pre_break_alert = true;
          post_break_alert = true;
        };
      }
      {
        id = "trayicon";
        enabled = true;
        version = "0.0.3";
        settings = {
          show_time_in_tray = false;
          show_long_time_in_tray = false;
          allow_disabling = true;
          disable_options = [
            {
              time = 30;
              unit = "minute";
            }
            {
              time = 1;
              unit = "hour";
            }
            {
              time = 2;
              unit = "hour";
            }
          ];
        };
      }
    ];
  };
in {
  # Each guard disables Safe Eyes while its condition holds. They coordinate
  # via flag files in $XDG_RUNTIME_DIR/safeeyes-guards/, so any combination
  # being active keeps Safe Eyes off until all conditions clear.
  # To drop a guard: delete its file and remove its import below.
  imports = [
    ./obsbot-guard.nix
    ./game-guard.nix
    ./hyprland-game-guard.nix
    ./screenshare-guard.nix
    ./media-guard.nix
  ];

  services.safeeyes.enable = true;

  # HM orders safeeyes Before=graphical-session.target, which deadlocks against
  # the tray-watcher wait below (the bar provides the watcher but starts after
  # the session) — a 30s startup stall. Run it after the session instead.
  systemd.user.services.safeeyes.Unit = {
    Before = lib.mkForce [];
    After = ["graphical-session.target"];
  };

  # Wait (up to 30s) for the tray watcher so the trayicon plugin doesn't error
  # if the bar hasn't registered it yet.
  systemd.user.services.safeeyes.Service.ExecStartPre = let
    wait = pkgs.writeShellScript "wait-for-statusnotifierwatcher" ''
      for _ in $(seq 1 30); do
        ${pkgs.systemd}/bin/busctl --user call \
          org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
          NameHasOwner s org.kde.StatusNotifierWatcher 2>/dev/null \
          | grep -q true && exit 0
        sleep 1
      done
    '';
  in "${wait}";

  xdg.configFile."safeeyes/safeeyes.json".text = builtins.toJSON safeeyesConfig;
}
