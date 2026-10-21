# Steam wrapper inside game-output: what a game needs on an HDR output.
# Unset on SDR outputs, where games may switch to HDR anyway.
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
