#!/usr/bin/env bash
# Registers every ghq base clone gwq knows about as a t3code project, so a
# fresh clone shows up without the manual "Add Project" file-picker walk, and
# removes any registered project whose path is gone (rename, gwq worktree
# promotion, deleted clone). Skips gwq's own worktrees. New paths are filtered
# out before calling t3 and added in parallel — each `t3 project add` costs
# ~0.5s of process-spawn overhead regardless of outcome, so that's what
# dominates a few-hundred-repo sync.
set -euo pipefail

state_db="${T3CODE_STATE_DB:-$HOME/.t3/userdata/state.sqlite}"

if [ ! -f "$state_db" ]; then
  echo "t3code-sync-projects: no state db at $state_db — start t3code once first" >&2
  exit 1
fi

known=$(sqlite3 "$state_db" \
  "select workspace_root from projection_projects where deleted_at is null;")

gwq list -g --json | jq -r '.[] | select(.is_main) | .path' |
  grep -vFxf <(printf '%s\n' "$known") |
  xargs -P "$(nproc)" -I{} t3 project add {}

printf '%s\n' "$known" | while IFS= read -r workspace_root; do
  [ -z "$workspace_root" ] && continue
  # This checkout lives outside the ghq tree by convention and is hand
  # registered, not gwq-managed — never let a scan treat it as stale.
  [ "$workspace_root" = "$HOME/nix-config" ] && continue
  if [ ! -d "$workspace_root" ]; then
    echo "t3code-sync-projects: removing $workspace_root (missing)" >&2
    t3 project remove "$workspace_root"
  fi
done
