# SDR game mode's decisions, run against a fake hyprctl that serves fixture state and logs every command.
{
  pkgs,
  lib,
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

  monitorsJson = cm: ''
    [{"name":"DP-3","activeWorkspace":{"id":6},"colorManagementPreset":"${cm}","disabled":false},
     {"name":"HDMI-A-1","activeWorkspace":{"id":3},"colorManagementPreset":"srgb","disabled":false}]
  '';
  game = {
    tags ? ''["game*"]'',
    fullscreen ? 2,
    xwayland ? true,
    workspace ? 6,
  }: ''{"fullscreen":${toString fullscreen},"workspace":{"id":${toString workspace}},"xwayland":${lib.boolToString xwayland},"tags":${tags}}'';
in
  pkgs.runCommand "sdr-game-mode-test" {nativeBuildInputs = [pkgs.coreutils pkgs.gnugrep];} ''
    set -euo pipefail
    export HYPRLAND_INSTANCE_SIGNATURE=test

    # scenario <name> <monitors.json> <clients.json> [workspaces.json]: one reconcile pass, then the exit trap.
    scenario() {
      export FIXTURE="$PWD/$1" XDG_RUNTIME_DIR="$PWD/$1/run"
      mkdir -p "$XDG_RUNTIME_DIR"
      printf '%s' "$2" > "$FIXTURE/monitors.json"
      printf '%s' "$3" > "$FIXTURE/clients.json"
      printf '%s' "''${4:-[]}" > "$FIXTURE/workspaces.json"
      : > "$FIXTURE/commands.log"
      # No event socket in the sandbox, so the listener ends right after the first reconcile.
      ${lib.getExe switch} > "$FIXTURE/out.log" 2>&1 || true
    }
    expect_commands() {
      local got
      got=$(cat "$FIXTURE/commands.log")
      if [ "$got" != "$1" ]; then
        printf 'FAIL %s: expected commands:\n%s\ngot:\n%s\n' "$(basename "$FIXTURE")" "$1" "$got" >&2
        cat "$FIXTURE/out.log" >&2
        exit 1
      fi
    }
    sdr_rule="DP-3,3840x2160@240.0,3840x0,1.000000,transform,0,vrr,0,bitdepth,10,cm,srgb"

    echo "switches an HDR monitor to sRGB for a fullscreen XWayland game"
    scenario switches '${monitorsJson "hdr"}' '[${game {}}]'
    expect_commands "keyword monitor $sdr_rule"

    echo "leaves the monitor in HDR for a game tagged keep-hdr"
    scenario keep-hdr '${monitorsJson "hdr"}' '[${game {tags = ''["game*","keep-hdr*"]'';}}]'
    expect_commands ""

    echo "leaves the monitor in HDR while the session toggle is paused"
    mkdir -p paused/run && touch paused/run/sdr-game-mode.paused
    scenario paused '${monitorsJson "hdr"}' '[${game {}}]'
    expect_commands ""

    echo "leaves the monitor in HDR for a Wayland game, which can carry HDR itself"
    scenario wayland '${monitorsJson "hdr"}' '[${game {xwayland = false;}}]'
    expect_commands ""

    echo "leaves the monitor in HDR for a maximized game"
    scenario maximized '${monitorsJson "hdr"}' '[${game {fullscreen = 1;}}]'
    expect_commands ""

    echo "ignores a fullscreen game on another workspace"
    scenario other-workspace '${monitorsJson "hdr"}' '[${game {workspace = 4;}}]'
    expect_commands ""

    echo "moves a special workspace off the monitor before switching, since it blocks direct scanout"
    scenario special '${monitorsJson "hdr"}' '[${game {}}]' '[{"id":-99,"name":"special:special","monitor":"DP-3"}]'
    expect_commands "dispatch moveworkspacetomonitor special:special HDMI-A-1
    keyword monitor $sdr_rule"

    echo "reloads to restore HDR once no SDR game is fullscreen"
    scenario restore '${monitorsJson "srgb"}' '[]'
    expect_commands "reload
    reload"

    echo "never touches a monitor not declared HDR"
    scenario sdr-monitor '[{"name":"HDMI-A-1","activeWorkspace":{"id":6},"colorManagementPreset":"srgb","disabled":false}]' '[${game {}}]'
    expect_commands ""

    echo "reports a rejected switch instead of claiming it switched"
    REJECT="invalid resolution" scenario rejected '${monitorsJson "hdr"}' '[${game {}}]'
    grep -q "was rejected: invalid resolution" rejected/out.log || { echo "FAIL rejected: no rejection logged" >&2; cat rejected/out.log >&2; exit 1; }
    if grep -q "switched it to sRGB" rejected/out.log; then echo "FAIL rejected: claimed the switch" >&2; exit 1; fi

    touch $out
  ''
