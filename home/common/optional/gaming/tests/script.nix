# SDR game mode's decisions, run against a fake hyprctl that serves fixture state and logs every command; cases in ./sdr-game-mode.bats.
{
  pkgs,
  lib,
  harness,
  ...
}: let
  monitor = output: x: {
    inherit output x;
    enabled = true;
    hdr = true;
    width = 3840;
    height = 2160;
    refreshRate = 240;
    y = 0;
    scale = 1.0;
    transform = "normal";
    vrr = "off";
    bitdepth = 10;
    mirror = null;
    icc = null;
    sdrMaxLuminance = 203;
    sdrMinLuminance = null;
    sdrBrightness = null;
    sdrSaturation = null;
    sdrEotf = null;
    supportsWideColor = null;
    supportsHdr = null;
    minLuminance = null;
    maxLuminance = null;
    maxAvgLuminance = null;
    reserved = null;
  };

  # Serves $FIXTURE/<query>.json for `-j` queries; answers `ok` to everything else, or $REJECT when set.
  fakeHyprctl = pkgs.writeShellScriptBin "hyprctl" ''
    if [ "$1" = -j ]; then
      cat "$FIXTURE/$2.json"
      exit 0
    fi
    echo "$*" >> "$FIXTURE/commands.log"
    printf '%s' "''${REJECT:-ok}"
  '';

  inherit
    (import ../_sdr-game-mode.nix {
      inherit lib pkgs;
      hyprland = fakeHyprctl;
      hdrMonitors = [(monitor "DP-3" 3840)];
    })
    switch
    ;

  monitorsWith = cm: [
    {
      id = 2;
      name = "DP-3";
      activeWorkspace.id = 6;
      colorManagementPreset = cm;
      disabled = false;
    }
    {
      id = 0;
      name = "HDMI-A-1";
      activeWorkspace.id = 3;
      colorManagementPreset = "srgb";
      disabled = false;
    }
  ];
  # pid null: the test splices in a live process for the daemon to read /proc from.
  game = {
    tags ? ["game*"],
    fullscreen ? 2,
    xwayland ? true,
    workspace ? 6,
    class ? "steam_app_620",
    pid ? 1,
  }: {
    address = "0xgame";
    monitor = 2;
    workspace.id = workspace;
    inherit tags fullscreen xwayland class pid;
  };
  gamescope = game {
    xwayland = false;
    class = "gamescope";
    pid = null;
  };

  # Hyprland's state per case; `after` is its state and the event once the first reconcile has run.
  cases = {
    switches.clients = [(game {})];
    keep-hdr.clients = [(game {tags = ["game*" "keep-hdr*"];})];
    paused.clients = [(game {})];
    wayland.clients = [(game {xwayland = false;})];
    gamescope-sdr.clients = [gamescope];
    gamescope-hdr.clients = [gamescope];
    maximized.clients = [(game {fullscreen = 1;})];
    other-workspace.clients = [(game {workspace = 4;})];
    special = {
      clients = [(game {})];
      workspaces = [
        {
          id = -99;
          name = "special:special";
          monitor = "DP-3";
        }
      ];
    };
    unfullscreened = {
      clients = [(game {})];
      after = {
        event = "fullscreen>>0";
        monitors = monitorsWith "srgb";
        clients = [(game {fullscreen = 0;})];
      };
    };
    closed = {
      clients = [(game {})];
      after = {
        event = "closewindow>>0xgame";
        monitors = monitorsWith "srgb";
        clients = [];
      };
    };
    moved = {
      clients = [(game {})];
      after = {
        event = "movewindowv2>>0xgame,3,3";
        monitors = monitorsWith "srgb";
        clients = [
          {
            address = "0xgame";
            monitor = 0;
            fullscreen = 0;
            workspace.id = 3;
            xwayland = true;
            tags = ["game*"];
          }
        ];
      };
    };
    restore = {
      monitors = monitorsWith "srgb";
      clients = [];
    };
    sdr-monitor = {
      monitors = [
        {
          id = 0;
          name = "HDMI-A-1";
          activeWorkspace.id = 6;
          colorManagementPreset = "srgb";
          disabled = false;
        }
      ];
      clients = [(game {})];
    };
    rejected.clients = [(game {})];
  };
in
  harness.bats "sdr-game-mode-test" [./sdr-game-mode.bats] {
    nativeBuildInputs = [pkgs.coreutils pkgs.jq pkgs.socat];
    sdrGameMode = lib.getExe switch;
    fixtures = pkgs.writeText "sdr-game-mode-cases.json" (builtins.toJSON (lib.mapAttrs (_: c:
      {
        monitors = monitorsWith "hdr";
        workspaces = [];
      }
      // c)
    cases));
  }
