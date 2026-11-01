# Shared by ./prune.bats and ./hooks.bats: one tmux server and state dir per test.

common_setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  # C, not UTF-8, on purpose: that is where tmux rewrites control characters
  # in -F output, which is how a delimiter-based parse broke here.
  export LC_ALL=C
  # tmux derives default-shell from SHELL; pin it so "idle" is well defined.
  export SHELL=${bash:?}
  export HOME=$BATS_TEST_TMPDIR/home TERM=xterm-256color
  export XDG_STATE_HOME=$HOME/.local/state
  # prune reaches the default socket, so the per-test server is per TMUX_TMPDIR.
  export TMUX_TMPDIR=$BATS_TEST_TMPDIR/run
  mkdir -p "$HOME" "$TMUX_TMPDIR"
  sd=$XDG_STATE_HOME/tmux/last-attached
  tm=(tmux -f /dev/null)
  day=86400
}

common_teardown() {
  "${tm[@]}" kill-server 2>/dev/null || true
}

# The server it forks would otherwise hold bats's fd 3.
new_session() { "${tm[@]}" new-session -d "$@" 3>&-; }

key() { printf '%s' "$1" | basenc --base64url -w 0; }
stamp() { cat "$sd/$(key "$1")" 2>/dev/null; }
backdate() { printf '%s\n' "$(($(date +%s) - $2))" >"$sd/$(key "$1")"; }
stale() { backdate "$1" $((4 * day)); }
alive() { "${tm[@]}" list-sessions -F '#{session_name}' 2>/dev/null | grep -Fxq "$1"; }

assert_stamped_now() {
  local at
  at=$(stamp "$1")
  assert_regex "$at" '^[0-9]+$'
  assert [ $(($(date +%s) - at)) -lt 60 ]
}
