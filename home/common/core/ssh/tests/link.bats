# The REAL tmux-ssh-auth-sock-link against a stub tmux:
#   list-clients     -> $CLIENTS, lines of "<activity> <client-name>"
#   show-environment -> SSH_AUTH_SOCK=$SESSION_SOCK, omitted when unset; fails when $ENV_FAIL
#   list-clients     -> fails when $CLIENTS_FAIL
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
  export SSH_AUTH_SOCK_PROBE_TIMEOUT=1
  export CLIENTS=$work/clients
  export SETENV_LOG=$work/setenv
  unset DBUS_SESSION_BUS_ADDRESS ENV_FAIL CLIENTS_FAIL
  refused=$work/map/.no-agent
  : >"$CLIENTS"
  : >"$SETENV_LOG"
}

teardown() {
  local pid
  for pid in $(jobs -p); do kill "$pid" 2>/dev/null || true; done
}

# A live agent: forwarded sockets must answer a probe, not merely exist.
mkagent() {
  ssh-agent -D -a "$work/$1" >/dev/null 2>&1 3>&- &
  for _ in $(seq 50); do
    [ -S "$work/$1" ] && return 0
    sleep 0.1
  done
  fail "ssh-agent never created $work/$1"
}

# A bound socket nobody listens on: what a departed connection leaves behind.
mksock() {
  python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$work/$1"
}

# Accepts and never answers, like a forwarded socket whose laptop went to sleep.
mkstalled() {
  python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(); time.sleep(60)' "$work/$1" 3>&- &
  for _ in $(seq 50); do
    [ -S "$work/$1" ] && return 0
    sleep 0.1
  done
  fail "stalled socket $work/$1 never appeared"
}

client() { ln -sfn "$work/$2" "$SSH_AUTH_SOCK_MAP/dev+pts+$1"; }

@test "attach records the client's agent and aims the link at it" {
  mkagent agentA
  export SESSION_SOCK=$work/agentA
  run "$linkScript" attach /dev/pts/1
  assert_success
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_LINK"
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_MAP/dev+pts+1"
}

@test "the link follows the most recently active client, not the newest attach" {
  mkagent agentA
  mkagent agentB
  client 1 agentA
  client 2 agentB
  printf '100 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
  "$linkScript" active
  assert_symlink_to "$work/agentB" "$SSH_AUTH_SOCK_LINK"

  printf '300 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
  "$linkScript" active
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_LINK"
}

@test "a most recent client whose agent died refuses rather than falling back to an older one" {
  mkagent agentA
  mksock gone
  client 2 gone
  client 1 agentA
  printf '100 /dev/pts/1\n999 /dev/pts/2\n' >"$CLIENTS"
  "$linkScript" active
  assert_equal "$(readlink "$SSH_AUTH_SOCK_LINK")" "$refused"
}

@test "a stalled forwarded agent is refused instead of hanging the caller" {
  mkstalled asleep
  export SESSION_SOCK=$work/asleep
  run timeout 10 "$linkScript" attach /dev/pts/1
  assert_success
  assert_equal "$(readlink "$SSH_AUTH_SOCK_LINK")" "$refused"
}

@test "a client that brought no agent refuses rather than reaching another agent" {
  mkagent agentA
  ln -sfn "$work/agentA" "$SSH_AUTH_SOCK_LINK"
  "$linkScript" attach /dev/pts/4
  assert_equal "$(readlink "$SSH_AUTH_SOCK_LINK")" "$refused"
  assert_equal "$(readlink "$SSH_AUTH_SOCK_MAP/dev+pts+4")" "$refused"
}

@test "detach with a survivor hands the link to the client still attached" {
  mkagent agentA
  mkagent agentB
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
  mkagent agentA
  export SESSION_SOCK=$work/agentA
  "$linkScript" attach /dev/pts/1
  run cat "$SETENV_LOG"
  assert_line "SSH_AUTH_SOCK $SSH_AUTH_SOCK_LINK"
  assert_line -- "-g SSH_AUTH_SOCK $SSH_AUTH_SOCK_LINK"
}

@test "a client inheriting the stable link does not record a self-reference" {
  mkagent agentA
  ln -sfn "$work/agentA" "$SSH_AUTH_SOCK_LINK"
  export SESSION_SOCK=$SSH_AUTH_SOCK_LINK
  "$linkScript" attach /dev/pts/3
  assert_not_exists "$SSH_AUTH_SOCK_MAP/dev+pts+3"
}

@test "an entry for a client that is no longer attached is retired" {
  mkagent agentA
  mkagent agentB
  client 8 agentB
  client 2 agentB
  printf '100 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
  export SESSION_SOCK=$work/agentA
  "$linkScript" attach /dev/pts/1
  assert_not_exists "$SSH_AUTH_SOCK_MAP/dev+pts+8"
  assert_exists "$SSH_AUTH_SOCK_MAP/dev+pts+1"
  assert_exists "$SSH_AUTH_SOCK_MAP/dev+pts+2"
}

@test "an attached client keeps its entry after its agent dies, so it goes on blocking fallback" {
  mkagent agentA
  client 9 gone
  printf '100 /dev/pts/1\n200 /dev/pts/9\n' >"$CLIENTS"
  export SESSION_SOCK=$work/agentA
  "$linkScript" attach /dev/pts/1
  assert_equal "$(readlink "$SSH_AUTH_SOCK_MAP/dev+pts+9")" "$work/gone"
}

@test "a client name that is not a device path is refused" {
  mkagent agentA
  export SESSION_SOCK=$work/agentA
  "$linkScript" attach ../escape
  assert_not_exists "$SSH_AUTH_SOCK_MAP/../escape"
}

@test "a link that cannot be written is reported, not announced as refused" {
  mkdir -p "$SSH_AUTH_SOCK_LINK/occupied"
  run "$linkScript" attach /dev/pts/4
  assert_output --partial "cannot update $SSH_AUTH_SOCK_LINK"
  refute_output --partial "signing is refused"
}

@test "entries are kept when tmux cannot list its clients" {
  mkagent agentA
  client 9 gone
  export SESSION_SOCK=$work/agentA CLIENTS_FAIL=1
  run "$linkScript" attach /dev/pts/1
  assert_failure
  assert_output --partial "leaving the link and its records as they are"
  assert_equal "$(readlink "$SSH_AUTH_SOCK_MAP/dev+pts+9")" "$work/gone"
}

@test "an attaching client is not recorded when its session environment cannot be read" {
  export ENV_FAIL=1
  run "$linkScript" attach /dev/pts/1
  assert_output --partial "cannot read the session environment"
  assert_not_exists "$SSH_AUTH_SOCK_MAP/dev+pts+1"
}

@test "a failed client listing leaves the link where it is" {
  mkagent agentA
  ln -sfn "$work/agentA" "$SSH_AUTH_SOCK_LINK"
  export CLIENTS_FAIL=1
  run "$linkScript" active
  assert_output --partial "cannot list tmux clients"
  assert_symlink_to "$work/agentA" "$SSH_AUTH_SOCK_LINK"
}

@test "a run that cannot get the lock gives up with a report instead of racing" {
  exec 8>"$SSH_AUTH_SOCK_MAP/.lock"
  flock 8
  export SSH_AUTH_SOCK_LOCK_WAIT=1
  run "$linkScript" active
  exec 8>&-
  assert_failure
  assert_output --partial "another run held"
}
