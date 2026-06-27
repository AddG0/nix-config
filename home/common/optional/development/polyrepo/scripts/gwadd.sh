#!/usr/bin/env bash
# gwadd [--no-session] [gwq-add-flags] <branch>
#   Create a gwq worktree as sibling of the primary clone, with `--<branch>`
#   suffix, then drop into a sesh/tmux session for it. Bypasses gwq's URL parser
#   (which drops GitLab subgroups and gets fooled by insteadOf URL rewrites) by
#   passing an explicit path.
#
#   Pattern based on ryoushin's gwadd helper
#   (zenn.dev/ryoushin/articles/a95b9bc5fb1055), but using `--` instead of `=`
#   as the suffix separator: `=` collides with `-javaagent:<path>=<args>`
#   parsing (breaks JaCoCo in Gradle/Maven test runs) and is invalid in Docker
#   image tags. `--` has zero tool collisions.
#
#   --no-session: just create the worktree, don't open a session.

# Split out our own --no-session flag; everything else passes through to gwq.
no_session=0
has_branch_flag=0
args=()
for arg in "$@"; do
  case "$arg" in
  --no-session) no_session=1 ;;
  -b | --branch)
    has_branch_flag=1
    args+=("$arg")
    ;;
  *) args+=("$arg") ;;
  esac
done
set -- "${args[@]}"

if [[ $# -eq 0 ]]; then
  echo "usage: gwadd [--no-session] [gwq-add-flags] <branch>" >&2
  exit 1
fi

primary=$(git worktree list --porcelain 2>/dev/null |
  awk '/^worktree /{print $2; exit}')

if [[ -z $primary ]]; then
  echo "gwadd: not in a git repo" >&2
  exit 1
fi

# Last positional is the branch name; sanitize `/` to `-`.
branch=${*: -1}
target="${primary}--${branch//\//-}"

# rev-parse only sees already-fetched refs, so an unfetched remote branch reads
# as missing here — fetch first if you meant to track the remote.
if [[ $has_branch_flag -eq 0 ]] && ! git rev-parse --verify --quiet "$branch" >/dev/null; then
  printf "gwadd: branch '%s' doesn't exist. Create it? [y/N] " "$branch" >&2
  read -r reply
  case "$reply" in
  [Yy]*) set -- -b "$@" ;;
  *)
    echo "gwadd: aborted" >&2
    exit 1
    ;;
  esac
fi

# set -e aborts here if gwq add fails, so we never connect to a half-made tree.
gwq add "$@" "$target"

if [[ $no_session -eq 0 ]]; then
  # From inside tmux sesh switches the client; outside it attaches a new
  # session. Session name is the dir basename (tmux-safe with `--`).
  exec sesh connect "$target"
fi
