# Builds a gamescope prefix for Steam's launchOptions.wrappers.
# Laptops resolve the native mode at launch via hyprctl (follows the active
# display); desktops bake the declared primary at build. Neither re-checks
# mid-game. Opt in per-game: launchOptions.wrappers = [gamemoderun] ++ gamescope;
# Skip for: anti-cheat (EAC), games needing the Steam overlay,
# PROTON_ENABLE_WAYLAND=1 titles, and games you want to tile freely.
#
# `env -u WAYLAND_DISPLAY` was previously prepended to each wrapper list: it hid
# the Wayland socket so gamescope used the SDL/Xwayland backend instead of its
# nested Wayland backend, dodging a wineserver hang on exit (leaked outer
# socket, gamescope#1396). Removed — the Wayland backend renders correctly,
# while SDL freezes-until-resize on Hyprland+NVIDIA. To restore, prepend to each
# branch's list below:  "env" "-u" "WAYLAND_DISPLAY"
{
  lib,
  pkgs,
  hyprctl,
  isLaptop,
  primaryMonitor,
  hdrArgs,
}: {extraArgs ? []}:
if isLaptop
then let
  launcher = pkgs.writeShellApplication {
    name = "gamescope-focused-monitor";
    runtimeInputs = [pkgs.gamescope pkgs.jq];
    text = ''
      W=${toString primaryMonitor.width}
      H=${toString primaryMonitor.height}
      R=${toString primaryMonitor.refreshRate}
      res=$("${hyprctl}" monitors -j 2>/dev/null \
        | jq -r '(map(select(.focused))[0] // .[0]) | "\(.width) \(.height) \(.refreshRate | round)"' 2>/dev/null) || res=""
      if [ -n "$res" ]; then
        read -r W H R <<<"$res"
      fi
      exec gamescope -W "$W" -H "$H" -w "$W" -h "$H" -r "$R" -f \
        ${lib.escapeShellArgs (hdrArgs ++ extraArgs)} -- "$@"
    '';
  };
in [(lib.getExe launcher)]
else
  [
    (lib.getExe pkgs.gamescope)
    "-W"
    (toString primaryMonitor.width)
    "-H"
    (toString primaryMonitor.height)
    "-w"
    (toString primaryMonitor.width)
    "-h"
    (toString primaryMonitor.height)
    "-r"
    (toString primaryMonitor.refreshRate)
    "-f"
  ]
  ++ hdrArgs
  ++ extraArgs
  ++ ["--"]
