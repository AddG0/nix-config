# Where the agent-link lines land in the zshrc the module renders, relative to oh-my-zsh.

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
