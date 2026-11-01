# The REAL tmux-ssh-auth-sock-link against a stub tmux:
#   list-clients     -> $CLIENTS, lines of "<activity> <client-name>"
#   show-environment -> SSH_AUTH_SOCK=$SESSION_SOCK, omitted when unset
#   set-environment  -> appended to $SETENV_LOG

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  export TMUX_SSH_LINK_TMUX=$tmuxStub
  work=$BATS_TEST_TMPDIR
  mkdir -p "$work/map"
  export SSH_AUTH_SOCK_LINK=$work/link
  export SSH_AUTH_SOCK_MAP=$work/map
  export CLIENTS=$work/clients
  export SETENV_LOG=$work/setenv
  : >"$CLIENTS"
  : >"$SETENV_LOG"
}

# A real AF_UNIX socket, since the script gates on -S.
mksock() {
  python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$work/$1"
}

client() { ln -sfn "$work/$2" "$SSH_AUTH_SOCK_MAP/dev+pts+$1"; }

@test "attach records the client's agent and aims the link at it" {
  mksock agentA
  export SESSION_SOCK=$work/agentA
  run "$linkScript" attach /dev/pts/1
  assert_success
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_LINK"
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_MAP/dev+pts+1"
}

@test "the link follows the most recently active client, not the newest attach" {
  mksock agentA
  mksock agentB
  client 1 agentA
  client 2 agentB
  printf '100 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
  "$linkScript" active
  assert_symlink_to "$work/agentB" "$SSH_AUTH_SOCK_LINK"

  printf '300 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
  "$linkScript" active
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_LINK"
}

@test "a client with a dead agent is skipped in favour of a live one" {
  mksock agentA
  client 2 gone
  client 1 agentA
  printf '100 /dev/pts/1\n999 /dev/pts/2\n' >"$CLIENTS"
  "$linkScript" active
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_LINK"
}

@test "detach with a survivor hands the link to the client still attached" {
  mksock agentA
  mksock agentB
  client 1 agentA
  client 2 agentB
  ln -sfn "$work/agentB" "$SSH_AUTH_SOCK_LINK"
  printf '100 /dev/pts/1\n' >"$CLIENTS"
  "$linkScript" detach
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_LINK"
}

@test "with nobody attached the link is left dead, so callers fail fast" {
  ln -sfn "$work/gone" "$SSH_AUTH_SOCK_LINK"
  "$linkScript" detach
  assert_equal "$(readlink "$SSH_AUTH_SOCK_LINK")" "$work/gone"
  assert_not_exists "$SSH_AUTH_SOCK_LINK"
}

@test "new panes are handed the link, not the raw per-connection socket" {
  mksock agentA
  export SESSION_SOCK=$work/agentA
  "$linkScript" attach /dev/pts/1
  run cat "$SETENV_LOG"
  assert_line "SSH_AUTH_SOCK $SSH_AUTH_SOCK_LINK"
  assert_line -- "-g SSH_AUTH_SOCK $SSH_AUTH_SOCK_LINK"
}

@test "a client that brought no agent does not overwrite the map with the link" {
  mksock agentA
  ln -sfn "$work/agentA" "$SSH_AUTH_SOCK_LINK"
  export SESSION_SOCK=$SSH_AUTH_SOCK_LINK
  "$linkScript" attach /dev/pts/3
  assert_not_exists "$SSH_AUTH_SOCK_MAP/dev+pts+3"
}

@test "an entry for a client that is no longer attached is retired" {
  mksock agentA
  mksock agentB
  client 8 agentB
  client 2 agentB
  printf '100 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
  export SESSION_SOCK=$work/agentA
  "$linkScript" attach /dev/pts/1
  assert_not_exists "$SSH_AUTH_SOCK_MAP/dev+pts+8"
  assert_exists "$SSH_AUTH_SOCK_MAP/dev+pts+1"
  assert_exists "$SSH_AUTH_SOCK_MAP/dev+pts+2"
}

@test "a map entry whose agent died is garbage collected" {
  mksock agentA
  client 9 gone
  export SESSION_SOCK=$work/agentA
  "$linkScript" attach /dev/pts/1
  assert_not_exists "$SSH_AUTH_SOCK_MAP/dev+pts+9"
}

@test "a client name that is not a device path is refused" {
  mksock agentA
  export SESSION_SOCK=$work/agentA
  "$linkScript" attach ../escape
  assert_not_exists "$SSH_AUTH_SOCK_MAP/../escape"
}
