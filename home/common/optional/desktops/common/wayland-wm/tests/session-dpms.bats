# The REAL session-dpms, built with fixture commands for Hyprland and niri that echo their name and state.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
}

@test "runs Hyprland's command in a Hyprland session" {
  run env XDG_CURRENT_DESKTOP=Hyprland "$sessionDpms" off
  assert_success
  assert_output hyprland-off
  run env XDG_CURRENT_DESKTOP=Hyprland "$sessionDpms" on
  assert_success
  assert_output hyprland-on
}

@test "runs niri's command in a niri session on the same host" {
  run env XDG_CURRENT_DESKTOP=niri "$sessionDpms" off
  assert_success
  assert_output niri-off
}

@test "finds the compositor in a colon-separated desktop list" {
  run env XDG_CURRENT_DESKTOP=GNOME:niri "$sessionDpms" on
  assert_success
  assert_output niri-on
}

@test "fails, naming the desktop, when the session has no command" {
  run env XDG_CURRENT_DESKTOP=KDE "$sessionDpms" off
  assert_failure 1
  assert_output --partial "XDG_CURRENT_DESKTOP='KDE'"
}

@test "rejects a state other than off or on" {
  run env XDG_CURRENT_DESKTOP=Hyprland "$sessionDpms" sleep
  assert_failure 2
  assert_output "session-dpms: expected off or on, got 'sleep'"
}
