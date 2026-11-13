# game-defaults' wrapper chain, focused-output's compositor queries, game-output's HDR lookup and
# ReShade preset rewriting, each against stubs; the cases live in the .bats files beside this.
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
  # KWin reports DP-2 focused; its current mode is the second of its two.
  kscreenJson = pkgs.writeText "kscreen.json" (builtins.toJSON {
    outputs = [
      {
        name = "eDP-1";
        currentModeId = "1";
        modes = [
          {
            id = "1";
            size = {
              width = 1920;
              height = 1200;
            };
            refreshRate = 120.0;
          }
        ];
      }
      {
        name = "DP-2";
        currentModeId = "3";
        modes = [
          {
            id = "2";
            size = {
              width = 1920;
              height = 1080;
            };
            refreshRate = 60.0;
          }
          {
            id = "3";
            size = {
              width = 3440;
              height = 1440;
            };
            refreshRate = 143.981;
          }
        ];
      }
    ];
  });
  focusedOutput = import ../focused-output.nix {
    inherit lib pkgs;
    hyprctl = pkgs.writeShellScript "hyprctl" "exit 1";
    busctl = pkgs.writeShellScript "busctl" ''echo '{"type":"s","data":["DP-2"]}' '';
    kscreenDoctor = pkgs.writeShellScript "kscreen-doctor" "cat ${kscreenJson}";
  };
  gameOutput = import ../game-output.nix {
    inherit lib pkgs;
    # Prints $FOCUSED as the focused output, or fails when it is unset.
    focusedOutput = pkgs.writeShellScript "focused-output" ''[ -n "''${FOCUSED:-}" ] && echo "$FOCUSED"'';
    monitors = [panel];
    primaryMonitor = panel;
  };
  reportHdr = pkgs.writeShellScript "report-hdr" ''
    echo "GAME_OUTPUT_HDR=$GAME_OUTPUT_HDR"
  '';
  reportMode = pkgs.writeShellScript "report-mode" ''
    echo "$GAME_OUTPUT_W $GAME_OUTPUT_H $GAME_OUTPUT_R"
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
  harness.bats "steam-game-defaults" [./game-defaults.bats ./focused-output.bats ./game-output.bats ./reshade.bats] {
    gameDefaults = lib.getExe gameDefaults;
    inherit game focusedOutput gameOutput reportHdr reportMode presetOut presetWant;
  }
