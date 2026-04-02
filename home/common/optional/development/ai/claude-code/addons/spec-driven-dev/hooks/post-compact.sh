#!/usr/bin/env bash
# Post-compaction context restoration (runs via SessionStart with matcher="compact").
# Re-injects spec context after auto-compaction to prevent spec drift.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CWD="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
SPEC_DIR="$CWD/.claude/specs"

[ -d "$SPEC_DIR" ] || exit 0

ACTIVE=""
for tasks_file in "$SPEC_DIR"/*/tasks.md; do
  [ -f "$tasks_file" ] || continue
  SPEC_NAME=$(basename "$(dirname "$tasks_file")")
  TOTAL=$(grep -cE '^- \[.\] ### Task' "$tasks_file" 2>/dev/null || echo 0)
  DONE=$(grep -cE '^- \[x\] ### Task' "$tasks_file" 2>/dev/null || echo 0)
  REMAINING=$((TOTAL - DONE))

  if [ "$REMAINING" -gt 0 ]; then
    NEXT_TASK=$(grep -m1 -A5 '^- \[ \] ### Task' "$tasks_file" | head -6 || true)
    ACTIVE="${ACTIVE}SPEC: ${SPEC_NAME} (${DONE}/${TOTAL} complete)"$'\n'
    if [ -n "$NEXT_TASK" ]; then
      ACTIVE="${ACTIVE}NEXT TASK: ${NEXT_TASK}"$'\n'
    fi
  fi
done

if [ -n "$ACTIVE" ]; then
  printf "CONTEXT RESTORED AFTER COMPACTION:\n%s\n" "$ACTIVE"
  printf "Spec files are in .claude/specs/. Re-read them if you need full context.\n"
  printf "Use /spec-status for current progress.\n"
fi
