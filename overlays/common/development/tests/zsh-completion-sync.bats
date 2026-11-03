# The first-prompt hook (PATH and XDG_DATA_DIRS scans), run against fpath, PATH and XDG_DATA_DIRS built from a symlinked profile.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  root=$BATS_TEST_TMPDIR
  mkdir -p "$root/real/bin" "$root/real/share/zsh/site-functions" "$root/dev/bin" "$root/dev/share/zsh/site-functions"
  printf '#compdef foo\n' >"$root/real/share/zsh/site-functions/_foo"
  printf '#compdef bar\n' >"$root/dev/share/zsh/site-functions/_bar"
  ln -s "$root/real" "$root/profile"
}

# Prints how many entries the first prompt added to fpath, then fpath itself.
first_prompt() {
  local path_dirs=$1
  # env -i drops PATH, so zsh has to be named by its full path.
  env -i HOME="$root" XDG_DATA_DIRS="$root/profile/share" "$(command -v zsh)" -f -c '
    path=('"$path_dirs"')
    fpath=('"$root"'/profile/share/zsh/site-functions $fpath)
    autoload -Uz compinit && compinit -D
    zstyle ":completion-sync:path" enabled true
    source '"$plugin"'
    before=${#fpath}
    _completion_sync:hook
    print "added=$(( ${#fpath} - before ))"
    print -l -- $fpath
  '
}

@test "a profile already on fpath through its symlink is not added again under its store path" {
  run first_prompt "$root/profile/bin"
  assert_success
  assert_line "added=0"
  refute_line "$root/real/share/zsh/site-functions"
}

@test "a devshell directory not yet on fpath is still added" {
  run first_prompt "$root/dev/bin $root/profile/bin"
  assert_success
  assert_line "added=1"
  assert_line "$root/dev/share/zsh/site-functions"
}
