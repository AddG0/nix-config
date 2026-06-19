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
  # ./next-event installs the calendar bar-widget plugin; it's enabled + placed below.
  imports = [inputs.noctalia.homeModules.default ./next-event];

  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;

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
          ["tray" "calendar" "bluetooth" "input_volume" "notifications" "volume"]
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

      # The calendar widget (installed via ./next-event).
      plugins.enabled = ["addg/next-event"];
      widget.calendar.type = "addg/next-event:agenda";

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

  # Launch via Hyprland exec-once rather than the systemd user service.
  wayland.windowManager.hyprland.settings.exec-once = ["${lib.getExe noctaliaPkg}"];

  # Restart noctalia when the system timezone changes. The system-level
  # automatic-timezoned ExecStartPost (running as root) touches
  # $XDG_RUNTIME_DIR/tz-changed after updating env; this path unit reacts and
  # respawns noctalia so its clock picks up the new zone (running processes
  # don't see TZ env-var changes).
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
        # Act as a *restart* only. At boot, automatic-timezoned touches the
        # tz-changed marker very early (before Hyprland is ready), firing this
        # unit. If we launched noctalia here we'd win the single-instance lock
        # and Hyprland's exec-once would bail with "already running" — leaving
        # no usable bar. So bail unless noctalia is already up; exec-once owns
        # the initial launch.
        if ! ${pkgs.procps}/bin/pgrep -x noctalia >/dev/null; then
          exit 0
        fi
        TZ=$(${pkgs.coreutils}/bin/readlink -f /etc/localtime | ${pkgs.gnugrep}/bin/grep -oP '(?<=zoneinfo/).*' || echo "UTC")
        export TZ
        ${pkgs.procps}/bin/pkill -x noctalia || true
        ${pkgs.coreutils}/bin/sleep 0.5
        # Spawn noctalia in an auto-named transient user service so it outlives
        # this oneshot (--scope would block until noctalia exits, leaving the
        # restart unit stuck in "activating" and preventing re-triggers). No
        # fixed --unit name to avoid name collisions across rapid re-triggers.
        ${pkgs.systemd}/bin/systemd-run --user --collect \
          --description="Noctalia shell (respawned)" \
          --setenv=TZ="$TZ" \
          ${lib.getExe noctaliaPkg}
      '';
    };
  };
}
