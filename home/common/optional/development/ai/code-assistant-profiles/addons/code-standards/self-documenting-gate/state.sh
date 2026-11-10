# shellcheck shell=bash
# What the self-documenting gate's hooks share, prepended to each by hooks.nix: where state lives and how a tree is snapshotted.

shopt -s inherit_errexit # a failure inside $(...) fails the hook instead of passing it silently

# Returns 1 outside a repo, which needs no gate, and 2 when git refuses the repo, after printing why.
repo_root() {
  local out
  if out=$(git -C "$1" rev-parse --show-toplevel 2>&1); then
    printf '%s\n' "$out"
  elif [[ $out == *"not a git repository"* ]]; then
    return 1
  else
    printf 'self-documenting: %s\n' "$out" >&2
    return 2
  fi
}

# In the worktree's git dir, so it survives a reboot and each linked worktree has its own.
baseline_file() {
  local git_dir
  git_dir=$(git -C "$1" rev-parse --path-format=absolute --git-dir)
  printf '%s/self-documenting/baselines/%s\n' "$git_dir" "$2"
}

# A per-session index that only caches stat data, so unchanged files aren't rehashed; losing it costs time, not correctness.
snapshot_index() {
  local key
  key=$(printf %s "$1" | sha1sum | cut -c1-12)
  printf '%s/claude-self-documenting/%s-%s.index\n' "${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}" "$2" "$key"
}

# The only errors --ignore-errors may skip past: an unreadable file and a nested repo with no commit.
skipped_only() {
  ! grep -vE -e '^error: open\(".*"\): Permission denied$' -e "^error: '.*' does not have a commit checked out$" \
    -e "^error: unable to index file '.*'$" -e '^$' <<<"$1" >/dev/null
}

# Every non-ignored file now, tracked or not, as a tree; unreadable files and empty nested repos are left out.
snapshot_tree() {
  local index real attempt errors
  index=$(snapshot_index "$1" "$2")
  mkdir -p "$(dirname "$index")"
  real=$(git -C "$1" rev-parse --path-format=absolute --git-path index)
  if [ ! -f "$index" ] && [ -f "$real" ]; then
    cp -p "$real" "$index" # mtime kept, so git's racy-clean check still covers the copied entries
  fi
  # Any other error, like a file that vanished mid-scan, gets another try.
  for attempt in 1 2 3; do
    if errors=$(GIT_INDEX_FILE=$index git -C "$1" add -A --ignore-errors 2>&1 >/dev/null) || skipped_only "$errors"; then
      if GIT_INDEX_FILE=$index git -C "$1" write-tree; then
        return 0
      fi
      printf 'self-documenting: could not write a snapshot of %s\n' "$1" >&2
      return 1
    fi
  done
  printf 'self-documenting: could not snapshot %s after %s tries:\n%s\n' "$1" "$attempt" "$errors" >&2
  return 1
}

record_baseline() {
  local file tree
  file=$(baseline_file "$1" "$2")
  mkdir -p "$(dirname "$file")"
  tree=$(snapshot_tree "$1" "$2")
  printf '%s\n' "$tree" >"$file"
}
