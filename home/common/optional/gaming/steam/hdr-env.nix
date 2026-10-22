# Innermost Steam wrapper: HDR env for games whose HDR can reach the compositor
# (Wine Wayland or gamescope); an XWayland window can't carry HDR.
{
  lib,
  pkgs,
}:
lib.getExe (pkgs.writeShellApplication {
  name = "hdr-env";
  text = ''
    [ "''${GAME_OUTPUT_HDR:-0}" = 1 ] || exec "$@"
    [ "''${PROTON_ENABLE_WAYLAND:-0}" = 1 ] || [ -n "''${GAMESCOPE_WAYLAND_DISPLAY:-}" ] || exec "$@"
    # DXVK only offers HDR to the game when told Windows HDR is on.
    export DXVK_HDR=1
    exec "$@"
  '';
})
