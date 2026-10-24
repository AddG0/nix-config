# session-dpms runs the entry for the session's compositor, whatever else the host has.
{
  pkgs,
  lib,
  ...
}: let
  dpms = import ../_session-dpms.nix {
    inherit lib pkgs;
    commands = {
      Hyprland = {
        off = "echo hyprland-off";
        on = "echo hyprland-on";
      };
      niri = {
        off = "echo niri-off";
        on = "echo niri-on";
      };
    };
  };
  run = lib.getExe dpms;
in
  pkgs.runCommand "session-dpms-test" {} ''
    set -euo pipefail
    expect() {
      if [ "$2" != "$3" ]; then
        printf 'FAIL %s: expected %s, got %s\n' "$1" "$2" "$3" >&2
        exit 1
      fi
    }

    echo "runs Hyprland's command in a Hyprland session"
    expect hyprland-off hyprland-off "$(XDG_CURRENT_DESKTOP=Hyprland ${run} off)"
    expect hyprland-on hyprland-on "$(XDG_CURRENT_DESKTOP=Hyprland ${run} on)"

    echo "runs niri's command in a niri session on the same host"
    expect niri-off niri-off "$(XDG_CURRENT_DESKTOP=niri ${run} off)"

    echo "finds the compositor in a colon-separated desktop list"
    expect list niri-on "$(XDG_CURRENT_DESKTOP=GNOME:niri ${run} on)"

    echo "fails, naming the desktop, when the session has no command"
    if msg=$(XDG_CURRENT_DESKTOP=KDE ${run} off 2>&1); then
      echo "FAIL unknown desktop: exited 0" >&2
      exit 1
    fi
    case "$msg" in *"XDG_CURRENT_DESKTOP='KDE'"*) ;; *) echo "FAIL unknown desktop: $msg" >&2; exit 1 ;; esac

    echo "rejects a state other than off or on"
    if XDG_CURRENT_DESKTOP=Hyprland ${run} sleep 2>/dev/null; then
      echo "FAIL bad state: exited 0" >&2
      exit 1
    fi

    touch $out
  ''
