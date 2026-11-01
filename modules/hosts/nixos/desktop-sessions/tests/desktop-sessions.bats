# start-session against rendered entries, and the launcher choosing a desktop by
# the user's default-session file. Each started session writes to $OUT_LOG: its
# arguments, or "<desktop> <XDG_CURRENT_DESKTOP> <XDG_SESSION_DESKTOP>".

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export OUT_LOG=$BATS_TEST_TMPDIR/out.log
  export HOME=$BATS_TEST_TMPDIR/home
  unset XDG_CONFIG_HOME
  choice=$HOME/.config/desktops/default-session
  mkdir -p "${choice%/*}"
}

@test "start-session runs the named session's Exec= with its arguments" {
  run "$startSession" hyprland-uwsm
  assert_success
  assert_equal "$(cat "$OUT_LOG")" $'start\nhyprland.desktop'
}

@test "start-session runs only the entry's first Exec=, not a desktop action's" {
  run "$startSession" with-action
  assert_success
  assert_equal "$(cat "$OUT_LOG")" main
}

@test "start-session refuses a session with no entry, naming it and where it looked" {
  run "$startSession" niri
  assert_failure
  assert_output --partial "no session 'niri' in $sessionsDir"
}

@test "the launcher starts the user's default desktop with its session variables" {
  printf 'niri\n' >"$choice"
  run "$launcher"
  assert_success
  assert_equal "$(cat "$OUT_LOG")" "niri niri niri"
  refute_output --partial "starting plasma"
}

@test "the launcher falls back to the host's desktop when the user has no default, and says why" {
  run "$launcher"
  assert_success
  assert_equal "$(cat "$OUT_LOG")" "plasma KDE plasma"
  assert_output --partial "no default session in $choice; starting plasma"
}

@test "the launcher treats an empty default like a missing one" {
  : >"$choice"
  run "$launcher"
  assert_success
  assert_equal "$(cat "$OUT_LOG")" "plasma KDE plasma"
  assert_output --partial "no default session in $choice; starting plasma"
}

@test "the launcher falls back when the default names no desktop here, naming it and this host's desktops" {
  printf 'gnome\n' >"$choice"
  run "$launcher"
  assert_success
  assert_equal "$(cat "$OUT_LOG")" "plasma KDE plasma"
  assert_output --partial "names 'gnome', not a desktop here (niri, plasma); starting plasma"
}
