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
# `..` satisfies the regexes above but escapes the ghq root.
[[ $project != *..* && $branch != *..* ]] || {
  echo "glmr-open: path traversal rejected" >&2
  exit 1
}

root=$(ghq root)
clone="$root/$host/$project"

# Any web page can fire glmr://, and the inner script reaches the network, so a
# human confirms the target — no host allowlist to keep in sync. Cancel and a
# failed/absent dialog both stop here. The field regexes above rule out Pango
# markup, so the target can't dress itself up as dialog chrome.
if [[ -d "$clone/.git" ]]; then
  action="Use existing clone"
else
  action="CLONE $host/$project"
fi
rc=0
yad --title="glmr-open" --image=dialog-question \
  --button=Cancel:1 --button=Open:0 \
  --text="Open merge request !$iid in Neovim?

host     $host
project  $project
branch   $branch

$action" || rc=$?
if [[ $rc != 0 ]]; then
  # 1 = Cancel, 252 = closed via ESC/WM. Anything else is yad itself failing,
  # which has to be loud — a broken dialog must not read as a silent decline.
  [[ $rc == 1 || $rc == 252 ]] && exit 0
  echo "glmr-open: confirmation dialog failed (yad exit $rc)" >&2
  exit 1
fi

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
