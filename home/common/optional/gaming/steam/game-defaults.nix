# Launch option for a game games.nix doesn't list: `game-defaults [--gamescope] %command%`
# runs it through the wrapper chain a listed game gets.
{
  lib,
  pkgs,
  gameOutput,
  gamemoderun,
  gamescope,
  gpuOffload,
}:
pkgs.writeShellApplication {
  name = "game-defaults";
  text = ''
    extra=()
    if [ "''${1:-}" = --gamescope ]; then
      extra=(${lib.escapeShellArgs gamescope})
      shift
    fi
    exec ${lib.escapeShellArgs [gameOutput gamemoderun]} "''${extra[@]}" ${lib.escapeShellArgs gpuOffload} "$@"
  '';
}
