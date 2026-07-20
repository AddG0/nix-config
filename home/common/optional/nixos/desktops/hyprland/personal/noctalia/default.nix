{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  isLaptop = config.hostSpec.hostType == "laptop";

  noctaliaPkg = pkgs.noctalia;
in {
  # ./plugins installs the bar-widget plugins (mkPlugin per dir); they're enabled + placed below.
  imports = [inputs.noctalia.homeModules.default ./plugins];

  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;

    # Run as a supervised systemd user service so noctalia auto-recovers when it
    # dies instead of staying down until relaunched by hand.
    systemd.enable = true;

    # Functional/structural settings. Pure visual choices (bar
    # rounding/margins/opacity, shadow direction, color scheme) live in
    # ./visuals.nix to keep all personal-flavor theming centralized.
    settings = {
      shell = {
        # 12-hour clock.
        time_format = "{:%I:%M %p}";
        date_format = "%A, %x";
        avatar_path = "/var/lib/AccountsService/icons/${config.home.username}";
      };

      # Widgets are named instance tokens; per-instance settings live in
      # [widget.*]. cpu/ram/input_volume are built-in seeded instances.
      bar.main = {
        position = "top";
        start = ["search" "clock" "cpu" "ram" "active_window" "media"];
        center = ["workspaces"];
        end =
          ["tray" "calendar" "bluetooth" "otd_mode" "input_volume" "notifications" "volume"]
          ++ lib.optionals isLaptop ["power_profile" "battery"]
          ++ ["control-center"];
      };

      # Search button opens walker instead of noctalia's built-in launcher.
      widget.search = {
        type = "custom_button";
        glyph = "search";
        tooltip = "Search";
        command = lib.getExe pkgs.walker;
      };

      # Bar-widget plugins (installed via ./plugins/*).
      plugins.enabled = ["addg/next-event" "addg/otd-mode"];
      widget.calendar.type = "addg/next-event:agenda";
      widget.otd_mode.type = "addg/otd-mode:switcher";

      # strftime clock formats.
      widget.clock = {
        format = "{:%I:%M %p %a, %b %d}";
        vertical_format = "{:%I\n%M %p}";
        tooltip_format = "{:%I:%M %p %a, %b %d}";
      };

      dock.enabled = false;

      # Show notifications on the primary monitor only on desktops; empty list
      # (all monitors) on laptops.
      notification.monitors = lib.optionals (!isLaptop) (
        map (m: m.output) (builtins.filter (m: m.primary or false) config.display.monitors)
      );

      weather = {
        enabled = true;
        unit = "imperial"; # metric = °C, imperial = °F
      };

      # Single source for weather + night light. auto_locate resolves
      # coordinates from IP; the fixed sunrise/sunset are an offline fallback
      # used only when no coordinates resolve.
      location = {
        auto_locate = true;
        sunrise = "06:30";
        sunset = "18:00";
      };

      # Night light follows the resolved location's sun times.
      nightlight = {
        enabled = true;
        temperature_day = 6000;
        temperature_night = 4500;
      };

      # Native CalDAV/Google calendar (no evolution-data-server). Accounts are
      # added in-app via Control Center -> Calendar (OAuth tokens are runtime
      # secrets); the panel opens from the existing `clock` bar widget.
      calendar = {
        enabled = true;
        refresh_minutes = 15;
      };

      wallpaper.enabled = false;
    };
  };

  # SUPER+C / SUPER+N open the calendar and notifications control-center tabs.
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER,c,exec,${lib.getExe noctaliaPkg} msg panel-toggle control-center calendar"
    "SUPER,n,exec,${lib.getExe noctaliaPkg} msg panel-toggle control-center notifications"
  ];

  # Override the module's Restart=on-failure: always also recovers from a clean
  # exit, e.g. a session-teardown that drops only noctalia.
  systemd.user.services.noctalia.Service = {
    Restart = lib.mkForce "always";
    RestartSec = 1;
    # Bust the resolved-location cache before launch so weather + night light
    # re-geolocate. As ExecStartPre it runs only after systemd has fully stopped
    # the old instance, so the exiting process can't rewrite what we just cleared.
    ExecStartPre = pkgs.writeShellScript "noctalia-bust-location" ''
      ${pkgs.coreutils}/bin/rm -f "''${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/location.json"
      ${pkgs.coreutils}/bin/rm -rf /tmp/noctalia-location
    '';
  };

  # Restart noctalia when the timezone changes so its clock/weather/night-light
  # follow the new zone (a running process doesn't see TZ env-var changes).
  # automatic-timezoned (root) touches $XDG_RUNTIME_DIR/tz-changed on change;
  # this path unit reacts.
  systemd.user.paths.noctalia-tz-watch = {
    Unit.Description = "Watch TZ-change marker to restart noctalia";
    Path = {
      PathChanged = "%t/tz-changed";
      Unit = "noctalia-tz-restart.service";
    };
    Install.WantedBy = ["default.target"];
  };

  systemd.user.services.noctalia-tz-restart = {
    Unit = {
      Description = "Respawn noctalia after timezone change";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "noctalia-tz-restart" ''
        # Publish the new zone to the user manager so the next start inherits it
        # (the unit's Environment= is empty; services inherit the manager env).
        TZ=$(${pkgs.coreutils}/bin/readlink -f /etc/localtime \
          | ${pkgs.gnugrep}/bin/grep -oP '(?<=zoneinfo/).*' || echo "UTC")
        ${pkgs.systemd}/bin/systemctl --user set-environment TZ="$TZ"

        # try-restart only restarts if already running; the initial launch is
        # owned by graphical-session.target, and at boot this marker often fires
        # before the session is up, so try-restart no-ops instead of racing it.
        ${pkgs.systemd}/bin/systemctl --user try-restart noctalia.service || true
      '';
    };
  };
}
