{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  isLaptop = config.hostSpec.hostType == "laptop";
  settingsPath = "$XDG_RUNTIME_DIR/noctalia/settings.json";
  nixSettings = config.xdg.configFile."noctalia/settings.json".source;
  # Noctalia caches weather in ~/.cache/noctalia/location.json
  # If weather is wrong after changing location, delete that file and restart.
  locate-city = pkgs.writeShellScript "noctalia-locate-city" ''
    mkdir -p "$XDG_RUNTIME_DIR/noctalia"
    HASH_FILE="$XDG_RUNTIME_DIR/noctalia/settings.hash"
    NEW_HASH=$(sha256sum ${nixSettings} | cut -d' ' -f1)
    OLD_HASH=$(cat "$HASH_FILE" 2>/dev/null || true)
    if [ ! -f ${settingsPath} ] || [ "$NEW_HASH" != "$OLD_HASH" ]; then
      cp --no-preserve=mode ${nixSettings} ${settingsPath}
      echo "$NEW_HASH" > "$HASH_FILE"
    fi
    for i in 1 2 3; do
      CITY=$(${pkgs.curl}/bin/curl -sf --max-time 5 "http://ip-api.com/json/?fields=city" | ${pkgs.jq}/bin/jq -r '.city // empty')
      [ -n "$CITY" ] && break
      sleep 2
    done
    if [ -n "$CITY" ]; then
      ${pkgs.jq}/bin/jq --arg city "$CITY" '.location.name = $city' ${settingsPath} > ${settingsPath}.tmp \
        && mv ${settingsPath}.tmp ${settingsPath}
    fi
  '';

  noctalia-start = pkgs.writeShellScript "noctalia-start" ''
    ${locate-city}
    export NOCTALIA_SETTINGS_FILE="$XDG_RUNTIME_DIR/noctalia/settings.json"
    exec noctalia-shell
  '';
in {
  imports = [inputs.noctalia.homeModules.default];

  programs.noctalia-shell = {
    enable = true;

    # Functional/structural noctalia settings. Pure visual choices (bar
    # rounding/margins/opacity, shadow direction, color scheme) live in
    # ./visuals.nix to keep all personal-flavor theming centralized.
    settings = {
      settingsVersion = 53;
      bar = {
        position = "top";
        widgets = {
          left = [
            {id = "Launcher";}
            {
              id = "Clock";
              formatHorizontal = "hh:mm AP ddd, MMM dd";
              formatVertical = "hh\nmm AP";
              tooltipFormat = "hh:mm AP ddd, MMM dd";
            }
            {id = "SystemMonitor";}
            {id = "ActiveWindow";}
            {id = "MediaMini";}
          ];
          right =
            [
              {id = "Tray";}
              {id = "Bluetooth";}
              {id = "Microphone";}
              {id = "NotificationHistory";}
              {id = "Volume";}
            ]
            ++ lib.optionals isLaptop [
              {id = "PowerProfile";}
              {id = "Battery";}
            ]
            ++ [{id = "ControlCenter";}];
        };
      };
      # When on a laptop we want to show notifications on all monitors since
      # we don't know which is the primary.
      notifications.monitors = lib.optionals (!isLaptop) (map (m: m.name) (builtins.filter (m: m.primary) config.display.monitors));
      dock.enabled = false;
      location.useFahrenheit = true;
      location.use12hourFormat = true;
      nightLight = {
        enabled = true;
        autoSchedule = false;
        manualSunrise = "06:30";
        manualSunset = "18:00";
        dayTemp = 6000;
        nightTemp = 4500;
      };
      general.avatarImage = "/var/lib/AccountsService/icons/${config.home.username}";
      wallpaper.enabled = false;
    };
  };

  # Systemd service deprecated upstream — launch via Hyprland exec-once instead.
  # The wrapper runs locate-city (copies settings + geo-lookup) then execs noctalia-shell.
  wayland.windowManager.hyprland.settings.exec-once = ["${noctalia-start}"];

  # Restart noctalia when the system timezone changes. The system-level
  # automatic-timezoned ExecStartPost (running as root) touches
  # $XDG_RUNTIME_DIR/tz-changed after updating env; this path unit reacts and
  # respawns noctalia so its Qt QDateTime picks up the new zone (running
  # processes don't see TZ env-var changes).
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
        TZ=$(${pkgs.coreutils}/bin/readlink -f /etc/localtime | ${pkgs.gnugrep}/bin/grep -oP '(?<=zoneinfo/).*' || echo "UTC")
        export TZ
        ${pkgs.procps}/bin/pkill -f quickshell || true
        ${pkgs.coreutils}/bin/sleep 0.5
        # Spawn noctalia in an auto-named transient user service so it outlives
        # this oneshot (--scope would block until noctalia exits, leaving the
        # restart unit stuck in "activating" and preventing re-triggers). No
        # fixed --unit name to avoid name collisions across rapid re-triggers.
        ${pkgs.systemd}/bin/systemd-run --user --collect \
          --description="Noctalia shell (respawned)" \
          --setenv=TZ="$TZ" \
          ${noctalia-start}
      '';
    };
  };
}
