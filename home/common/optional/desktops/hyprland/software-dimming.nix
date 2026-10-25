{
  config,
  pkgs,
  ...
}: let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  nightGamma = 70;
  nightStart = 21;
  nightEnd = 7;
  gammaScript = pkgs.writeShellScript "hypr-gamma" ''
    set -eu

    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hyprsunset"
    state_file="$state_dir/gamma"
    mkdir -p "$state_dir"

    current=100
    if [ -r "$state_file" ]; then
      read -r current < "$state_file" || current=100
    fi

    case "''${1:-}" in
      up)      next=$((current + 5)) ;;
      down)    next=$((current - 5)) ;;
      reset)   next=100 ;;
      restore) next="$current" ;;
      schedule)
        hour=$(date +%-H)
        if [ "$hour" -ge ${toString nightStart} ] || [ "$hour" -lt ${toString nightEnd} ]; then
          next=${toString nightGamma}
        else
          next=100
        fi
        ;;
      *)
        echo "usage: hypr-gamma {up|down|reset|restore|schedule}" >&2
        exit 2
        ;;
    esac

    if [ "$next" -lt 0 ];   then next=0;   fi
    if [ "$next" -gt 100 ]; then next=100; fi

    # Restore and a missed-schedule catch-up run at session start; hyprsunset's IPC may not be ready yet, so retry.
    if [ "''${1}" = "restore" ] || [ "''${1}" = "schedule" ]; then
      applied=0
      for _ in 1 2 3 4 5; do
        ${hyprctl} hyprsunset gamma "$next" >/dev/null 2>&1 && { applied=1; break; }
        sleep 1
      done
      if [ "$applied" -ne 1 ]; then
        echo "hypr-gamma: hyprsunset IPC unreachable after 5 tries; gamma $next not applied" >&2
        exit 1
      fi
    else
      ${hyprctl} hyprsunset gamma "$next" >/dev/null
    fi

    printf '%s\n' "$next" > "$state_file"
  '';
in {
  # Drives brightness via hyprsunset's CTM path, which (unlike a screen shader)
  # is not captured by wlr-screencopy — so screenshots aren't dimmed.
  services.hyprsunset.enable = true;

  # Reload-recovery handled by autostart.nix's exec-once relauncher.
  wayland.windowManager.hyprland.settings.exec-once = ["${gammaScript} restore"];

  wayland.windowManager.hyprland.extraConfig = ''
    unbind = ,XF86MonBrightnessUp
    unbind = ,XF86MonBrightnessDown
    binde = ,XF86MonBrightnessUp,exec,${gammaScript} up
    binde = ,XF86MonBrightnessDown,exec,${gammaScript} down
    bind = SUPERSHIFT,backslash,exec,${gammaScript} reset
  '';

  services.hyprsunset.systemdTarget = config.lib.hyprland.sessionUnit;

  systemd.user.services.hypr-gamma-schedule = {
    Unit = {
      Description = "Dim the screen at night via hyprsunset gamma";
      After = ["graphical-session.target"];
      PartOf = [config.lib.hyprland.sessionUnit];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${gammaScript} schedule";
    };
  };

  systemd.user.timers.hypr-gamma-schedule = {
    Unit = {
      Description = "Night dimming schedule";
      PartOf = [config.lib.hyprland.sessionUnit];
    };
    Timer = {
      OnCalendar = ["*-*-* ${toString nightStart}:00:00" "*-*-* ${toString nightEnd}:00:00"];
      Persistent = true;
    };
    Install.WantedBy = [config.lib.hyprland.sessionUnit];
  };
}
