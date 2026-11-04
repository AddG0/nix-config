# Where the rendered ssh config sends a hostsAddr host.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export HOME=$BATS_TEST_TMPDIR/home
  mkdir -p "$HOME/.ssh"
}

# ssh expands ~ from getpwuid, not $HOME, so the config is named with -F.
opt() {
  ssh -F "$1" -G "$3" 2>/dev/null | grep -i "^$2 " | cut -d' ' -f2-
}

@test "a hostsAddr host is reached at its address and port, with the agent forwarded" {
  assert_equal "$(opt "$sshConfig" hostname "$host")" "$hostAddr"
  assert_equal "$(opt "$sshConfig" port "$host")" "$sshPort"
  assert_equal "$(opt "$sshConfig" forwardagent "$host")" yes
}
