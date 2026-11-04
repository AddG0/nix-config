# Which agent a fresh shell ends up on, read from the 1Password hook in the rendered zshrc.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
}

# The 1Password hook, run under env -i so the build's own environment cannot decide the case.
agent() {
  env -i "$@" "$(command -v zsh)" -f -c 'source "$0"; print -r -- "${SSH_AUTH_SOCK:-none}"' "$BATS_TEST_TMPDIR/hook.zsh"
}

hook() {
  awk -v want="export SSH_AUTH_SOCK=\"$onePasswordAgent\"" \
    '{ l[NR] = $0 } index($0, want) { n = NR } END { if (n) print l[n-1] "\n" l[n] "\n" l[n+1] }' \
    "$zshrc" >"$BATS_TEST_TMPDIR/hook.zsh"
  [ -s "$BATS_TEST_TMPDIR/hook.zsh" ] || fail "no 1Password hook in the rendered zshrc"
}

@test "a local shell uses 1Password over the session's agent" {
  hook
  assert_equal "$(agent SSH_AUTH_SOCK=/run/gcr)" "$onePasswordAgent"
}

@test "an SSH session keeps the agent it forwarded" {
  hook
  assert_equal "$(agent SSH_CONNECTION=x SSH_AUTH_SOCK=/tmp/fwd)" /tmp/fwd
}

@test "an SSH session that forwarded no agent falls back to 1Password" {
  hook
  assert_equal "$(agent SSH_CONNECTION=x)" "$onePasswordAgent"
}

@test "a tmux pane keeps the link tmux handed it" {
  hook
  assert_equal "$(agent TMUX=x SSH_AUTH_SOCK=/tmp/link)" /tmp/link
}
