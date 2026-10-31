# game-defaults runs a game through the listed-game wrapper chain, adding gamescope only on request;
# a ReShade preset's effect file names are lowercased to match nix-reshade's shader files.
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

  # Presets ship with Windows line endings, as AMS2 Realistic's does.
  crlf = lines: pkgs.writeText "preset.ini" (lib.concatMapStrings (line: "${line}\r\n") lines);
  presetIn = crlf [
    "Techniques=DPX@DPX.fx,HDR@FakeHDR.fx"
    "TechniqueSorting=DPX@DPX.fx,HDR@FakeHDR.fx"
    ""
    "[DPX.fx]"
    "Colorfulness=2.325000"
    "RGB_C=0.370000,0.365000,0.350000"
  ];
  presetWant = crlf [
    "Techniques=DPX@dpx.fx,HDR@fakehdr.fx"
    "TechniqueSorting=DPX@dpx.fx,HDR@fakehdr.fx"
    ""
    "[dpx.fx]"
    "Colorfulness=2.325000"
    "RGB_C=0.370000,0.365000,0.350000"
  ];
  presetOut =
    (import ../reshade.nix {
        inherit lib;
        inherit (pkgs) runCommand;
        reshadePkgs = {
          reshade = "/fake/reshade";
          d3dcompiler_47-dll = "/fake/d3dcompiler";
          reshade-shaders.override = _: "/fake/shaders";
          reshadeShaders.SweetFX = "/fake/sweetfx";
        };
      } {
        preset = presetIn;
        presetName = "Look.ini";
        packs = ["SweetFX"];
      })
    .files
    .game
    .place
    ."Look.ini"
    .source;
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

    cmp -s ${presetOut} ${presetWant} \
      || fail "preset effect names not lowercased to match the shader files: $(cat -v ${presetOut})"

    touch "$out"
  ''
