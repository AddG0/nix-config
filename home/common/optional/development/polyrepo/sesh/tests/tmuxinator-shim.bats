# sesh parses `tmuxinator list -n` by dropping the header and trailing line, so the shim must match it byte for byte.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  export HOME=$BATS_TEST_TMPDIR/home
  unset XDG_CONFIG_HOME TMUXINATOR_CONFIG
  mkdir -p "$HOME"
}

project() {
  mkdir -p "$(dirname "$1")"
  printf 'name: %s\nroot: ~/\n' "$(basename "$1" .yml)" >"$1"
}

assert_same_as_tmuxinator() {
  "$real" list -n >"$BATS_TEST_TMPDIR/want"
  "$shim" list -n >"$BATS_TEST_TMPDIR/got"
  run diff -u "$BATS_TEST_TMPDIR/want" "$BATS_TEST_TMPDIR/got"
  assert_success
}

@test "lists XDG and ~/.tmuxinator projects together, subfolders in the name, dotfiles skipped" {
  project "$HOME/.config/tmuxinator/billing.yml"
  project "$HOME/.config/tmuxinator/work/api.yml"
  project "$HOME/.config/tmuxinator/.hidden.yml"
  project "$HOME/.config/tmuxinator/.drafts/wip.yml"
  project "$HOME/.tmuxinator/Zeta.yml"
  project "$HOME/.tmuxinator/alpha.yml"
  assert_same_as_tmuxinator
  assert_equal "$(wc -l <"$BATS_TEST_TMPDIR/got")" 5
}

@test "TMUXINATOR_CONFIG replaces the default directories" {
  project "$HOME/.config/tmuxinator/ignored.yml"
  export TMUXINATOR_CONFIG=$BATS_TEST_TMPDIR/custom
  project "$TMUXINATOR_CONFIG/only.yml"
  assert_same_as_tmuxinator
  run cat "$BATS_TEST_TMPDIR/got"
  refute_line "ignored"
}

@test "XDG_CONFIG_HOME moves the XDG directory" {
  export XDG_CONFIG_HOME=$BATS_TEST_TMPDIR/xdg
  project "$XDG_CONFIG_HOME/tmuxinator/moved.yml"
  assert_same_as_tmuxinator
}

@test "no project directories prints the header and an empty line" {
  assert_same_as_tmuxinator
}

@test "other commands reach the real tmuxinator" {
  run "$shim" version
  assert_success
  assert_output "$("$real" version)"
}
