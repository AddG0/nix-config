# Builds a gamescope prefix for Steam's wrappers, sized from the output
# game-output resolved; it is not re-checked mid-game. Opt in per-game:
# wrappers = [gamemoderun] ++ gamescope;
# Skip for: anti-cheat (EAC), games needing the Steam overlay,
# PROTON_ENABLE_WAYLAND=1 titles, and games you want to tile freely.
# Nested Wayland backend on purpose: SDL freezes-until-resize on Hyprland+NVIDIA
# (`env -u WAYLAND_DISPLAY` forces SDL, if gamescope#1396's exit hang returns).
{
  lib,
  pkgs,
}: extraArgs:
lib.singleton (lib.getExe (pkgs.writeShellApplication {
  name = "gamescope-output";
  runtimeInputs = [pkgs.gamescope];
  # GAME_OUTPUT_* arrive from game-output's environment.
  excludeShellChecks = ["SC2153"];
  text = ''
    # Unset inside the gamescope session, which already does this job; a nested
    # instance would die anyway (gamescope lacks wp_viewporter/wl_subcompositor).
    [ -n "''${GAME_OUTPUT_W:-}" ] || exec "$@"

    hdr_arg=()
    [ "$GAME_OUTPUT_HDR" = 1 ] && hdr_arg=(--hdr-enabled)
    # gamescope overwrites DXVK_HDR for the game before Hyprland's HDR info reaches it.
    [ -z "''${DXVK_HDR:-}" ] || set -- env DXVK_HDR="$DXVK_HDR" "$@"

    exec gamescope -W "$GAME_OUTPUT_W" -H "$GAME_OUTPUT_H" \
      -w "$GAME_OUTPUT_W" -h "$GAME_OUTPUT_H" -r "$GAME_OUTPUT_R" -f \
      "''${hdr_arg[@]}" ${lib.escapeShellArgs extraArgs} -- "$@"
  '';
}))
