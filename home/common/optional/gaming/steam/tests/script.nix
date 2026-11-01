# game-defaults' wrapper chain, game-output's HDR lookup and ReShade preset
# rewriting, each against stubs; the cases live in the .bats files beside this.
{
  harness,
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
    output = "desc:Test Panel 0x0000";
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
    echo "GAME_OUTPUT_HDR=$GAME_OUTPUT_HDR"
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
  harness.bats "steam-game-defaults" [./game-defaults.bats ./game-output.bats ./reshade.bats] {
    gameDefaults = lib.getExe gameDefaults;
    inherit game gameOutput reportHdr presetOut presetWant;
  }
