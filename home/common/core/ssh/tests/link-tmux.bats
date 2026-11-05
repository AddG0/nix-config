# The hooks the module installs, against a live tmux: pins tmux's format
# semantics, which the stub suite in ./link.bats takes on trust.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  work=$BATS_TEST_TMPDIR
  export HOME=$work/home TERM=xterm-256color
  mkdir -p "$HOME/.ssh"
  link=$HOME/.ssh/ssh_auth_sock
  tm=(tmux -L "itest-$BATS_TEST_NUMBER")

  mkagent agentA
  mkagent agentB
  mkfifo "$work/fifoA" "$work/fifoB"

  # Anything left holding fd 3 keeps bats waiting forever.
  "${tm[@]}" new-session -d -s t -x 80 -y 24 3>&-
  "${tm[@]}" source-file "$hooks"

  attach agentA fifoA
  exec 5>"$work/fifoA"
  wait_link "$work/agentA"
}

teardown() {
  exec 5>&- 6>&-
  "${tm[@]}" kill-server 2>/dev/null || true
  kill "${agents[@]}" 2>/dev/null || true
}

# Live agents, since the link probes a forwarded socket before aiming at it.
agents=()
mkagent() {
  ssh-agent -D -a "$work/$1" >/dev/null 2>&1 3>&- &
  agents+=("$!")
  for _ in $(seq 50); do
    [ -S "$work/$1" ] && return 0
    sleep 0.1
  done
  fail "ssh-agent never created $work/$1"
}

# script(1) only hands its child a pty when its own stdin is not /dev/null.
attach() {
  SSH_AUTH_SOCK=$work/$1 script -q -c "${tm[*]} attach -t t" /dev/null \
    <"$work/$2" >/dev/null 2>&1 3>&- &
}

# Hooks run backgrounded, so poll rather than guess a sleep.
wait_link() {
  local _
  for _ in $(seq 100); do
    [ "$(readlink "$link" 2>/dev/null)" = "$1" ] && return 0
    sleep 0.1
  done
  fail "link aims at '$(readlink "$link")', not $1"
}

@test "the link follows the client that attached" {
  assert_symlink_to "$work/agentA" "$link"
}

@test "a pane that never runs a shell rc still gets the link" {
  "${tm[@]}" new-window -t t: -d "sh -c 'printenv SSH_AUTH_SOCK > $work/paneenv'"
  for _ in $(seq 30); do
    [ -s "$work/paneenv" ] && break
    sleep 0.1
  done
  assert_equal "$(cat "$work/paneenv")" "$link"
}

@test "a second client takes the link" {
  attach agentB fifoB
  exec 6>"$work/fifoB"
  wait_link "$work/agentB"
}

@test "a client that creates its own session takes the link" {
  SSH_AUTH_SOCK=$work/agentB script -q -c "${tm[*]} new-session -A -s fresh" /dev/null \
    <"$work/fifoB" >/dev/null 2>&1 3>&- &
  exec 6>"$work/fifoB"
  wait_link "$work/agentB"
}

@test "typing at the first client moves the link back" {
  attach agentB fifoB
  exec 6>"$work/fifoB"
  wait_link "$work/agentB"
  # client_activity has 1 s resolution; a tie falls back to sorting pts names.
  sleep 1.1
  printf ' ' >&5
  wait_link "$work/agentA"
}
