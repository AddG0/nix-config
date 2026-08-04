#compdef gwadd

_gwadd_branches() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

  local -a locals remotes
  locals=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"})
  # Remote-only branches are valid targets — gwadd fetches them itself.
  remotes=(${(f)"$(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes 2>/dev/null)"})
  remotes=(${remotes:#HEAD})
  remotes=(${remotes:|locals})

  _describe -t local-branches 'local branch' locals
  _describe -t remote-branches 'remote branch' remotes
}

_gwadd() {
  # No -i or [path]: gwadd reads the last positional as the branch, path derived.
  _arguments -s -S \
    '--no-session[Create the worktree without opening a sesh session]' \
    '(-b --branch)'{-b,--branch}'[Create a new branch]' \
    '(-f --force)'{-f,--force}'[Overwrite existing directory]' \
    '--expires[Set expiration]:duration:(1h 12h 1d 7d 30d)' \
    '(-s --stay)'{-s,--stay}'[Stay in the worktree directory after creation]' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1:branch:_gwadd_branches'
}

_gwadd "$@"
