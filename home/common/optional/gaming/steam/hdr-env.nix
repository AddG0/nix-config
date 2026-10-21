# Steam wrapper inside game-output: what a game needs on an HDR output.
# Leaves DXVK_HDR unset on SDR outputs, where a game told HDR is on may switch to it.
{
  lib,
  pkgs,
}:
lib.getExe (pkgs.writeShellApplication {
  name = "hdr-env";
  text = ''
    [ "''${GAME_OUTPUT_HDR:-0}" = 1 ] || exec "$@"
    # DXVK only offers HDR to the game when told Windows HDR is on.
    export DXVK_HDR=1
    exec "$@"
  '';
})
