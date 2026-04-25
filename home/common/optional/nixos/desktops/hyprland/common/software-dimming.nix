{pkgs, ...}: let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
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
      *)
        echo "usage: hypr-gamma {up|down|reset|restore}" >&2
        exit 2
        ;;
    esac

    if [ "$next" -lt 0 ];   then next=0;   fi
    if [ "$next" -gt 100 ]; then next=100; fi

    # Restore runs at session start; hyprsunset's IPC may not be ready yet, so retry.
    if [ "''${1}" = "restore" ]; then
      for _ in 1 2 3 4 5; do
        ${hyprctl} hyprsunset gamma "$next" >/dev/null 2>&1 && break
        sleep 1
      done
    else
      ${hyprctl} hyprsunset gamma "$next" >/dev/null
    fi

    printf '%s\n' "$next" > "$state_file"
  '';
in {
  # Drives brightness via hyprsunset's CTM path, which (unlike a screen shader)
  # is not captured by wlr-screencopy — so screenshots aren't dimmed.
  services.hyprsunset.enable = true;

  wayland.windowManager.hyprland.settings.exec-once = ["${gammaScript} restore"];

  wayland.windowManager.hyprland.extraConfig = ''
    unbind = ,XF86MonBrightnessUp
    unbind = ,XF86MonBrightnessDown
    binde = ,XF86MonBrightnessUp,exec,${gammaScript} up
    binde = ,XF86MonBrightnessDown,exec,${gammaScript} down
    bind = SUPERSHIFT,backslash,exec,${gammaScript} reset
  '';
}
