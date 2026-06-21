#!/usr/bin/env bash
# ghq-sync - push the ghq repo you're currently in to another computer.
# Git-aware via gsync: excludes .git and respects .gitignore. The other machine
# is assumed to share this nix-config's ghq layout, so the repo lands at the
# same path under its ghq root (no destination path needed).
# Usage: ghq-sync <ssh-host> [extra rsync options...]

if [ $# -lt 1 ]; then
  echo "Usage: ghq-sync <ssh-host> [rsync-options...]"
  echo ""
  echo "Push the ghq repo you're currently in to the same path on another"
  echo "computer (assumed to share this nix-config's ghq layout)."
  echo ""
  echo "Examples:"
  echo "  ghq-sync laptop          # push current repo to laptop"
  echo "  ghq-sync user@host -n    # dry-run"
  exit 1
fi

HOST="$1"
shift

GHQ_ROOT="$(ghq root)"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || true
if [ -z "$REPO_ROOT" ]; then
  echo "ghq-sync: not inside a git repository." >&2
  exit 1
fi

# Must be a ghq-managed repo so its path maps cleanly onto the remote ghq root.
case "$REPO_ROOT/" in
"$GHQ_ROOT"/*) ;;
*)
  echo "ghq-sync: $REPO_ROOT is not under the ghq root ($GHQ_ROOT)." >&2
  exit 1
  ;;
esac

REL_REPO="${REPO_ROOT#"$GHQ_ROOT"/}" # e.g. github.com/owner/repo

# Map the ghq root onto the remote home (same nix-config => same layout). Fall
# back to the absolute path if the root somehow lives outside $HOME.
case "$GHQ_ROOT" in
"$HOME"/*) REMOTE_PATH="${GHQ_ROOT#"$HOME"/}/$REL_REPO" ;;
*) REMOTE_PATH="$GHQ_ROOT/$REL_REPO" ;;
esac

echo "ghq-sync: $REL_REPO -> $HOST:$REMOTE_PATH/"
cd "$REPO_ROOT" || exit 1
exec gsync "$@" ./ "$HOST:$REMOTE_PATH/"
