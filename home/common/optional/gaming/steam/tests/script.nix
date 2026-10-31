# game-defaults runs a game through the listed-game wrapper chain, adding gamescope only on request.
{
  pkgs,
  lib,
  ...
}: let
  stub = name:
    pkgs.writeShellScript name ''
      echo ${name} >>"$CHAIN"
      exec "$@"
    '';

  game = pkgs.writeShellScript "game" ''
    printf '%s\n' "$@" >"$ARGV"
    echo "''${OFFLOAD:-unset}" >"$OFFLOAD_SEEN"
  '';

  gameDefaults = import ../game-defaults.nix {
    inherit lib pkgs;
    gameOutput = stub "game-output";
    gamemoderun = stub "gamemoderun";
    gamescope = [(stub "gamescope")];
    gpuOffload = ["env" "OFFLOAD=1"];
  };
in
  pkgs.runCommand "steam-game-defaults" {} ''
    fail() { echo "FAIL: $*" >&2; exit 1; }
    export CHAIN=$PWD/chain ARGV=$PWD/argv OFFLOAD_SEEN=$PWD/offload
    run() { rm -f "$CHAIN" "$ARGV" "$OFFLOAD_SEEN"; ${lib.getExe gameDefaults} "$@"; }

    run ${game} "Steam App" -novr --gamescope
    [ "$(paste -sd' ' "$CHAIN")" = "game-output gamemoderun" ] \
      || fail "default chain without --gamescope: $(paste -sd' ' "$CHAIN")"
    [ "$(cat "$ARGV")" = "$(printf '%s\n' "Steam App" -novr --gamescope)" ] \
      || fail "game arguments altered: $(cat "$ARGV")"
    [ "$(cat "$OFFLOAD_SEEN")" = 1 ] || fail "GPU offload env did not reach the game"

    run --gamescope ${game} -novr
    [ "$(paste -sd' ' "$CHAIN")" = "game-output gamemoderun gamescope" ] \
      || fail "chain with --gamescope: $(paste -sd' ' "$CHAIN")"
    [ "$(cat "$ARGV")" = "-novr" ] || fail "--gamescope leaked into the game's arguments: $(cat "$ARGV")"

    touch "$out"
  ''
