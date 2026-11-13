# focused-output against stubs: hyprctl fails, KWin reports DP-2 focused.

setup() {
  bats_require_minimum_version 1.5.0
  bats_load_library bats-support
  bats_load_library bats-assert
}

@test "on Plasma it prints KWin's focused output at its current mode" {
  XDG_CURRENT_DESKTOP=KDE run "$focusedOutput"
  assert_success
  assert_output "DP-2 3440 1440 144"
}

@test "on Plasma GAME_OUTPUT_OVERRIDE picks the named output" {
  XDG_CURRENT_DESKTOP=KDE GAME_OUTPUT_OVERRIDE=eDP-1 run "$focusedOutput"
  assert_success
  assert_output "eDP-1 1920 1200 120"
}

@test "on Plasma an output that is not connected fails" {
  XDG_CURRENT_DESKTOP=KDE GAME_OUTPUT_OVERRIDE=HDMI-9 run --separate-stderr "$focusedOutput"
  assert_failure
  assert_output ""
}

@test "outside Plasma a failing hyprctl fails" {
  run --separate-stderr "$focusedOutput"
  assert_failure
  assert_output ""
}
