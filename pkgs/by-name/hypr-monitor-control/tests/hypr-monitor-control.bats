# The real hypr-monitor-control command against a fake hyprctl (see ./script.nix) reporting $monitorsJson and $workspacesJson.
#   $HYPRCTL_LOG  every hyprctl call that changes state (keyword, reload, dispatch), one per line

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export MONITORS_JSON=$monitorsJson WORKSPACES_JSON=$workspacesJson
  export HYPRCTL_LOG=$BATS_TEST_TMPDIR/hyprctl.log
  export XDG_STATE_HOME=$BATS_TEST_TMPDIR/state
  export NO_COLOR=1
  : >"$HYPRCTL_LOG"
}

hyprctl_calls() { cat "$HYPRCTL_LOG"; }

@test "rate switches the HDR laptop panel to 60 Hz, keeping position, scale, VRR, 10-bit and HDR" {
  run "$monitor" rate eDP-1 60
  assert_success
  assert_equal "$(hyprctl_calls)" "keyword monitor eDP-1,2560x1600@60,3170x-984,1.25,transform,0,vrr,1,bitdepth,10,cm,hdr"
}

@test "rate keeps a rotated SDR output's rotation and leaves bit depth and colour at defaults" {
  run "$monitor" rate DP-1 60
  assert_success
  assert_equal "$(hyprctl_calls)" "keyword monitor DP-1,1920x1080@60,5218x-984,1,transform,1,vrr,0"
}

@test "rate works on an output reporting no format or colour preset" {
  run "$monitor" rate HDMI-A-2 30
  assert_success
  assert_equal "$(hyprctl_calls)" "keyword monitor HDMI-A-2,1280x720@30,0x0,1,transform,0,vrr,0"
}

@test "rate refuses a disabled monitor, naming it, and sends nothing" {
  run "$monitor" rate DP-2 60
  assert_failure
  assert_output --partial "DP-2' is not active"
  assert_equal "$(hyprctl_calls)" ""
}

@test "rate fails with Hyprland's reply when it rejects the rule" {
  export HYPRCTL_REPLY='invalid syntax at "cm"'
  run "$monitor" rate eDP-1 60
  assert_failure
  assert_output --partial 'eDP-1: invalid syntax at "cm"'
}

@test "rate without a numeric rate prints usage and sends nothing" {
  run "$monitor" rate eDP-1 fast
  assert_failure
  assert_output --partial "Usage: hypr-monitor-control"
  assert_equal "$(hyprctl_calls)" ""
}

@test "disable then enable restores the monitor's full live spec" {
  run "$monitor" disable DP-1
  assert_success
  run "$monitor" enable DP-1
  assert_success
  assert_equal "$(hyprctl_calls)" "keyword monitor DP-1,disable
keyword monitor DP-1,1920x1080@119.88,5218x-984,1,transform,1,vrr,0"
}

@test "recover reloads, returns declared workspaces to their monitor and sweeps the rest onto the primary" {
  run "$monitor" recover
  assert_success
  assert_equal "$(hyprctl_calls)" "reload
dispatch moveworkspacetomonitor 1 DP-1
dispatch moveworkspacetomonitor 2 DP-1
dispatch moveworkspacetomonitor 5 eDP-1
dispatch moveworkspacetomonitor 7 eDP-1"
}

@test "recover with no declared layout refuses and changes nothing" {
  run "$monitorWithoutLayout" recover
  assert_failure
  assert_output --partial "no monitors declared"
  assert_equal "$(hyprctl_calls)" ""
}
