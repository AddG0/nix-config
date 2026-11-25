# Runs the REAL hypr-monitor-control command against a fake hyprctl; cases in ./hypr-monitor-control.bats.
{
  bats,
  hypr-monitor-control,
  runCommand,
  writeShellScriptBin,
}: let
  # Queries print $MONITORS_JSON (plus any monitor disabled through it), its active subset, or
  # $WORKSPACES_JSON; every other call is logged to $HYPRCTL_LOG, and `keyword` replies $HYPRCTL_REPLY (default ok).
  fakeHyprland = writeShellScriptBin "hyprctl" ''
    disabled=$HYPRCTL_LOG.disabled
    touch "$disabled"
    monitors() { jq --rawfile off "$disabled" 'map(.disabled = (.disabled or (.name as $n | $off | split("\n") | index($n) != null)))' "$MONITORS_JSON"; }
    case "$*" in
      "monitors all -j") monitors ;;
      "monitors -j") monitors | jq '[.[] | select(.disabled | not)]' ;;
      "-j workspaces") cat "$WORKSPACES_JSON" ;;
      keyword*)
        printf '%s\n' "$*" >>"$HYPRCTL_LOG"
        reply=''${HYPRCTL_REPLY:-ok}
        if [ "$reply" = ok ] && [[ "$3" == *,disable ]]; then echo "''${3%,disable}" >>"$disabled"; fi
        echo "$reply"
        ;;
      reload | dispatch*) printf '%s\n' "$*" >>"$HYPRCTL_LOG" ;;
      *)
        echo "fake hyprctl: unexpected call: $*" >&2
        exit 2
        ;;
    esac
  '';

  withLayout = hypr-monitor-control.override {
    hyprland = fakeHyprland;
    layout = {
      primaryMonitor = "eDP-1";
      workspaceMonitors = [
        {
          workspace = "1";
          monitor = "DP-1";
        }
        {
          workspace = "2";
          monitor = "DP-1";
        }
      ];
    };
  };
  withoutLayout = hypr-monitor-control.override {hyprland = fakeHyprland;};
in
  runCommand "hypr-monitor-control-script-test" {
    nativeBuildInputs = [(bats.withLibraries (p: [p.bats-support p.bats-assert]))];
    monitor = "${withLayout}/bin/hypr-monitor-control";
    monitorWithoutLayout = "${withoutLayout}/bin/hypr-monitor-control";
    monitorsJson = ./monitors.json;
    workspacesJson = ./workspaces.json;
  } ''
    bats ${./hypr-monitor-control.bats}
    touch "$out"
  ''
