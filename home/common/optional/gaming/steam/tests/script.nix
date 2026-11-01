# game-defaults runs a game through the listed-game wrapper chain, adding gamescope only on request;
# a ReShade preset's effect file names are lowercased to match nix-reshade's shader files.
# game-output reads HDR from a declared output whose name has spaces, as laptop panels' desc: names do.
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

  panel = {
    output = "desc:AU Optronics 0x8E9D";
    hdr = true;
    width = 2560;
    height = 1600;
    refreshRate = 165;
  };
  gameOutput = import ../game-output.nix {
    inherit lib pkgs;
    # No compositor to ask, so the declared primary is the target.
    hyprctl = pkgs.writeShellScript "hyprctl" "exit 1";
    monitors = [panel];
    primaryMonitor = panel;
  };
  reportHdr = pkgs.writeShellScript "report-hdr" ''
    echo "$GAME_OUTPUT_HDR" >"$HDR_SEEN"
  '';

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

    HDR_SEEN=$PWD/hdr ${gameOutput} ${reportHdr} 2>/dev/null \
      || fail "game-output with a declared output name containing spaces did not run"
    [ "$(cat "$PWD/hdr")" = 1 ] || fail "HDR of a declared output named with spaces was not read: $(cat "$PWD/hdr")"

    cmp -s ${presetOut} ${presetWant} \
      || fail "preset effect names not lowercased to match the shader files: $(cat -v ${presetOut})"

    touch "$out"
  ''
