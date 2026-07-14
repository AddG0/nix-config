#!/usr/bin/env bash
# glmr-open <url>
#
# Open a GitLab merge request for review in Neovim. Given
#   glmr://open?host=<h>&project=<url-encoded group/sub/proj>&iid=<n>&branch=<url-encoded branch>
# it resolves the ghq clone, makes a gwq worktree for the MR's branch via
# `gwadd` (so the primary checkout is never touched), and opens nvim in that
# worktree straight into the gitlab.nvim review. Quitting nvim tears the
# worktree back down (unless it has uncommitted changes).
set -euo pipefail

url=${1:-}
[[ -n $url ]] || {
  echo "glmr-open: missing url" >&2
  exit 1
}

qs=${url#*\?}
field() {
  local kv key val
  IFS='&' read -ra pairs <<<"$qs"
  for kv in "${pairs[@]}"; do
    key=${kv%%=*}
    val=${kv#*=}
    if [[ $key == "$1" ]]; then
      # minimal percent-decode (project uses %2F for its slashes)
      printf '%b' "${val//%/\\x}"
      return 0
    fi
  done
}
host=$(field host)
project=$(field project)
iid=$(field iid)
branch=$(field branch)

# Validate strictly — these values become a filesystem path and exec args.
[[ $host =~ ^[A-Za-z0-9.-]+$ ]] || {
  echo "glmr-open: bad host" >&2
  exit 1
}
[[ $project =~ ^[A-Za-z0-9._/-]+$ ]] || {
  echo "glmr-open: bad project" >&2
  exit 1
}
[[ $branch =~ ^[A-Za-z0-9._/-]+$ ]] || {
  echo "glmr-open: bad branch" >&2
  exit 1
}
[[ $iid =~ ^[0-9]+$ ]] || {
  echo "glmr-open: bad iid" >&2
  exit 1
}
# Only clone from hosts you trust — a rogue link must not make us `ghq get`
# arbitrary repos. Tighten this to your exact GitLab host.
case $host in
gitlab.com | gitlab.*) ;;
*)
  echo "glmr-open: host not allowed: $host" >&2
  exit 1
  ;;
esac

root=$(ghq root)
clone="$root/$host/$project"

# `bash -lc` gives the inner shell the interactive PATH (gwadd/ghq/nvim/git). The
# inner is single-quoted and takes $1..$4 as positional args, so the URL never
# enters the command string.
# shellcheck disable=SC2016
exec ghostty -e bash -lc '
  set -euo pipefail
  clone=$1 host=$2 project=$3 branch=$4
  [[ -d "$clone/.git" ]] || ghq get "$host/$project"
  cd "$clone"
  gwadd --no-session "$branch"
  target="${clone}--${branch//\//-}"
  cd "$target"
  nvim -c "lua vim.schedule(function() require(\"gitlab\").review() end)"
  # Review done: drop the worktree. git refuses a dirty tree, so uncommitted
  # work is never silently discarded; the branch ref survives regardless.
  cd "$clone"
  git worktree remove "$target" || {
    echo "glmr: kept worktree (uncommitted changes) — $target" >&2
    read -rp "press enter to close "
  }
' glmr-inner "$clone" "$host" "$project" "$branch"
