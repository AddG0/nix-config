#!/usr/bin/env bash
# Registers every ghq base clone gwq knows about as a t3code project, so a
# fresh clone shows up without the manual "Add Project" file-picker walk, and
# removes any registered project whose path is gone (rename, gwq worktree
# promotion, deleted clone). Skips gwq's own worktrees. New paths are filtered
# out before calling t3 — each `t3 project add` costs ~0.5s of process-spawn
# overhead regardless of outcome. Serial: with no server up, each add takes the
# data dir's lock without waiting, so parallel adds fail.
set -euo pipefail

state_db="${T3CODE_STATE_DB:-$HOME/.t3/userdata/statev2.sqlite}"
# A hand-registered checkout outside the ghq tree, never pruned as stale.
unmanaged="${T3CODE_SYNC_UNMANAGED:-}"

if [ ! -f "$state_db" ]; then
  echo "t3code-sync-projects: no state db at $state_db — start t3code once first" >&2
  exit 1
fi

known=$(sqlite3 "$state_db" \
  "select workspace_root from projection_projects where deleted_at is null;")

clones=$(gwq list -g --json | jq -r '.[] | select(.is_main) | .path')
unregistered=$(grep -vFxf <(printf '%s\n' "$known") <<<"$clones") || {
  grep_status=$?
  [ "$grep_status" -eq 1 ] || exit "$grep_status"
}
added=0
if [ -n "$unregistered" ]; then
  while IFS= read -r workspace_root; do
    t3 project add "$workspace_root"
    printf 'Added: %q\n' "$workspace_root"
    ((added += 1))
  done <<<"$unregistered"
fi

registered=0
removed=0
while IFS= read -r workspace_root; do
  [ -z "$workspace_root" ] && continue
  ((registered += 1))
  [ "$workspace_root" = "$unmanaged" ] && continue
  if [ ! -d "$workspace_root" ]; then
    t3 project remove "$workspace_root"
    printf 'Removed: %q\n' "$workspace_root"
    ((removed += 1))
  fi
done <<<"$known"

registered=$((registered + added - removed))
project_noun=projects
[ "$registered" -eq 1 ] && project_noun=project
if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  printf '%d %s synced (%d added, %d removed)\n' \
    "$registered" "$project_noun" "$added" "$removed"
elif [ -t 1 ]; then
  printf '%d %s already in sync\n' "$registered" "$project_noun"
fi
