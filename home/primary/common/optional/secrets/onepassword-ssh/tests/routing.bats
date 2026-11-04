# Which agent ssh asks, depending on whether the shell sits on the tmux link.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export HOME=$BATS_TEST_TMPDIR/home
  mkdir -p "$HOME/.ssh"
  link=$HOME/.ssh/ssh_auth_sock
  unset SSH_TTY
}

# ssh expands ~ from getpwuid, not $HOME, so the config is named with -F.
opt() {
  ssh -F "$1" -G "$3" 2>/dev/null | grep -i "^$2 " | cut -d' ' -f2-
}

@test "a local shell's ssh asks the 1Password agent" {
  export SSH_AUTH_SOCK=/run/gcr
  assert_equal "$(opt "$sshConfig" identityagent "$host")" "$onePasswordAgent"
}

@test "a shell on the tmux link keeps the link's agent instead of 1Password" {
  export SSH_AUTH_SOCK=$link
  assert_equal "$(opt "$sshConfig" identityagent "$host")" ""
}

@test "an SSH session keeps its forwarded agent instead of 1Password" {
  export SSH_TTY=/dev/pts/9 SSH_AUTH_SOCK=/tmp/forwarded
  assert_equal "$(opt "$sshConfig" identityagent "$host")" ""
}
