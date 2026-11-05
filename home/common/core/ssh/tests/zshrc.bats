# The agent-link lines in the zshrc the module renders.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
}

line() {
  local n
  n=$(grep -n "$2" "$1" | head -1 | cut -d: -f1)
  # fail inside $(...) cannot stop the caller, so return non-zero for errexit.
  [ -n "$n" ] || {
    echo "no line matching '$2' in the rendered zshrc" >&2
    return 1
  }
  echo "$n"
}

@test "the dead-socket clear runs before oh-my-zsh and the link claim after it" {
  clear=$(line "$zshrc" 'unset SSH_AUTH_SOCK')
  omz=$(line "$zshrc" 'source \$ZSH/oh-my-zsh.sh')
  claim=$(line "$zshrc" 'export SSH_AUTH_SOCK="\$HOME/.ssh/ssh_auth_sock"')
  assert [ "$clear" -lt "$omz" ]
  assert [ "$claim" -gt "$omz" ]
}

# A pane's shell starting with a live inherited agent, against a link aimed at $1.
pane_start() {
  mkdir -p "$BATS_TEST_TMPDIR/.ssh"
  python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$BATS_TEST_TMPDIR/inherited"
  ln -sfn "$1" "$BATS_TEST_TMPDIR/.ssh/ssh_auth_sock"
  HOME=$BATS_TEST_TMPDIR TMUX=test SSH_AUTH_SOCK=$BATS_TEST_TMPDIR/inherited zsh -fc 'source "$1" 2>/dev/null' _ "$zshrc"
}

@test "a pane's shell re-seeds a link whose agent is merely gone" {
  pane_start "$BATS_TEST_TMPDIR/gone"
  assert_equal "$(readlink "$BATS_TEST_TMPDIR/.ssh/ssh_auth_sock")" "$BATS_TEST_TMPDIR/inherited"
}

@test "a pane's shell leaves a refused link alone" {
  pane_start "$BATS_TEST_TMPDIR/.ssh/agent-by-client/.no-agent"
  assert_equal "$(readlink "$BATS_TEST_TMPDIR/.ssh/ssh_auth_sock")" "$BATS_TEST_TMPDIR/.ssh/agent-by-client/.no-agent"
}
