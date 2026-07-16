# Builds a gamescope prefix for Steam's launchOptions.wrappers.
# Laptops resolve the native mode at launch via hyprctl (follows the active
# display); desktops bake the declared primary at build. Neither re-checks
# mid-game. Opt in per-game: launchOptions.wrappers = [gamemoderun] ++ gamescope;
# Skip for: anti-cheat (EAC), games needing the Steam overlay,
# PROTON_ENABLE_WAYLAND=1 titles, and games you want to tile freely.
{
  lib,
  pkgs,
  hyprctl,
  isLaptop,
  primaryMonitor,
  hdrArgs,
}: {extraArgs ? []}:
# env -u WAYLAND_DISPLAY: else the leaked outer socket makes wineserver hang
# on exit — see github.com/ValveSoftware/gamescope/issues/1396
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
in ["env" "-u" "WAYLAND_DISPLAY" (lib.getExe launcher)]
else
  [
    "env"
    "-u"
    "WAYLAND_DISPLAY"
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
