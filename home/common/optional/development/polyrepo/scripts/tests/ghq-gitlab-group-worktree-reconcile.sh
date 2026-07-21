#!/usr/bin/env bash

set -euo pipefail

script_dir=$(dirname "$(realpath "$0")")
script=$(realpath "$script_dir/../ghq-gitlab-group.sh")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

root="$tmp/ghq"
group="my-org/team"
primary_repo="primary-repo"
branch="feature-branch"
stale_repo="stale-repo"
stale_repo_with_worktree="stale-repo-with-worktree"
repo_dir="$root/gitlab.com/$group/$primary_repo"
worktree_dir="$root/gitlab.com/$group/$primary_repo--$branch"
nested_repo_dir="$worktree_dir/vendor/cache"
stale_repo_dir="$root/gitlab.com/$group/$stale_repo"
protected_repo_dir="$root/gitlab.com/$group/$stale_repo_with_worktree"
protected_worktree_dir="$root/gitlab.com/$group/$stale_repo_with_worktree--$branch"
bin_dir="$tmp/bin"
glab_log="$tmp/glab.log"
mkdir -p \
  "$repo_dir/.git/worktrees/$primary_repo--$branch" \
  "$nested_repo_dir/.git" \
  "$stale_repo_dir/.git" \
  "$protected_repo_dir/.git/worktrees/$stale_repo_with_worktree--$branch" \
  "$worktree_dir" \
  "$protected_worktree_dir" \
  "$bin_dir"

printf 'gitdir: %s\n' "$repo_dir/.git/worktrees/$primary_repo--$branch" >"$worktree_dir/.git"
printf 'gitdir: %s\n' "$protected_repo_dir/.git/worktrees/$stale_repo_with_worktree--$branch" >"$protected_worktree_dir/.git"

cat >"$bin_dir/ghq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
root)
  printf '%s\n' "$TEST_GHQ_ROOT"
  ;;
get)
  exit 0
  ;;
*)
  echo "unexpected ghq invocation: $*" >&2
  exit 1
  ;;
esac
EOF

cat >"$bin_dir/glab" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TEST_GLAB_LOG"

if [[ ${1:-} == auth && ${2:-} == status ]]; then
  exit 0
fi

if [[ ${1:-} == api && ${2:-} == --paginate ]]; then
  printf '%s\n' '[{"path_with_namespace":"my-org/team/primary-repo"}]'
  exit 0
fi

if [[ ${1:-} == api && ${2:-} == projects/my-org%2Fteam%2Fprimary-repo--feature-branch ]]; then
  printf '%s\n' '404 Project Not Found (HTTP 404)' >&2
  exit 1
fi

if [[ ${1:-} == api && ${2:-} == projects/my-org%2Fteam%2Fstale-repo ]]; then
  printf '%s\n' '404 Project Not Found (HTTP 404)' >&2
  exit 1
fi

if [[ ${1:-} == api && ${2:-} == projects/my-org%2Fteam%2Fstale-repo-with-worktree ]]; then
  printf '%s\n' '404 Project Not Found (HTTP 404)' >&2
  exit 1
fi

if [[ ${1:-} == api && ${2:-} == projects/my-org%2Fteam%2Fprimary-repo--feature-branch%2Fvendor%2Fcache ]]; then
  printf '%s\n' '404 Project Not Found (HTTP 404)' >&2
  exit 1
fi

echo "unexpected glab invocation: $*" >&2
exit 1
EOF

chmod +x "$bin_dir/ghq" "$bin_dir/glab"

export PATH="$bin_dir:$PATH"
export TEST_GHQ_ROOT="$root"
export TEST_GLAB_LOG="$glab_log"

output=$("$script" "$group" 2>&1)

glab_calls=$(<"$glab_log")

if [[ -d $stale_repo_dir ]]; then
  printf 'expected stale primary clone to be removed, but it remains\n%s\n' "$output" >&2
  exit 1
fi

if [[ ! -d $worktree_dir ]]; then
  printf 'expected worktree to remain, but it was removed\n%s\n' "$output" >&2
  exit 1
fi

if [[ ! -d $protected_repo_dir ]]; then
  printf 'expected stale primary clone with linked worktrees to be kept, but it was removed\n%s\n' "$output" >&2
  exit 1
fi

if [[ ! -d $protected_worktree_dir ]]; then
  printf 'expected linked worktree for stale primary clone to remain, but it was removed\n%s\n' "$output" >&2
  exit 1
fi

if [[ ! -d $nested_repo_dir ]]; then
  printf 'expected nested repo inside worktree to remain, but it was removed\n%s\n' "$output" >&2
  exit 1
fi

if [[ $glab_calls != *"api projects/my-org%2Fteam%2Fstale-repo"* ]]; then
  printf 'expected stale primary clone to be queried, got:\n%s\n' "$glab_calls" >&2
  exit 1
fi

if [[ $glab_calls != *"api projects/my-org%2Fteam%2Fstale-repo-with-worktree"* ]]; then
  printf 'expected stale primary clone with linked worktrees to be queried, got:\n%s\n' "$glab_calls" >&2
  exit 1
fi

if [[ $glab_calls == *"api projects/my-org%2Fteam%2Fprimary-repo--feature-branch"* ]]; then
  printf 'expected linked worktree to be skipped, got:\n%s\n' "$glab_calls" >&2
  exit 1
fi

if [[ $glab_calls == *"api projects/my-org%2Fteam%2Fprimary-repo--feature-branch%2Fvendor%2Fcache"* ]]; then
  printf 'expected nested repo inside worktree to be skipped, got:\n%s\n' "$glab_calls" >&2
  exit 1
fi

if [[ $output != *"stale-repo"* ]]; then
  printf 'expected prune output for stale primary clone, got:\n%s\n' "$output" >&2
  exit 1
fi

if [[ $output != *"stale-repo-with-worktree (gone, has linked worktrees)"* ]]; then
  printf 'expected manual-review output for stale primary clone with linked worktrees, got:\n%s\n' "$output" >&2
  exit 1
fi

printf 'ok: worktree reconcile preserves linked worktrees\n'
