#!/usr/bin/env bash
# SessionStart hook: load steering context and active spec summary at session start.
# Fires once when a session begins or resumes.

INPUT=$(cat) || true
[ -n "$INPUT" ] || exit 0

CWD=$(echo "$INPUT" | jq -r '.cwd // empty') || true
CWD="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
STEERING_DIR="$CWD/.claude/steering"

# Load steering context summary
if [ -d "$STEERING_DIR" ]; then
	printf "PROJECT STEERING CONTEXT:\n"
	for doc in product.md tech.md structure.md; do
		if [ -f "$STEERING_DIR/$doc" ]; then
			TITLE=$(head -1 "$STEERING_DIR/$doc" | sed 's/^# //')
			printf "  %s: %s\n" "$doc" "$TITLE"
		fi
	done
	printf "\n"
fi

# Load active spec summary (task-level checkboxes: "- [ ] ### Task")
SPEC_DIR="$CWD/.claude/specs"
if [ -d "$SPEC_DIR" ]; then
	ACTIVE=""
	for tasks_file in "$SPEC_DIR"/*/tasks.md; do
		[ -f "$tasks_file" ] || continue
		SPEC_NAME=$(basename "$(dirname "$tasks_file")")
		TOTAL=$(grep -cE '^- \[.\] ### Task' "$tasks_file" 2>/dev/null || echo 0)
		DONE=$(grep -cE '^- \[x\] ### Task' "$tasks_file" 2>/dev/null || echo 0)
		REMAINING=$((TOTAL - DONE))
		if [ "$REMAINING" -gt 0 ]; then
			ACTIVE="${ACTIVE}  ${SPEC_NAME}: ${DONE}/${TOTAL} tasks complete"$'\n'
		fi
	done

	if [ -n "$ACTIVE" ]; then
		printf "ACTIVE SPECS:\n%s" "$ACTIVE"
		printf "Use /spec-status for details or /spec-execute <name> <task#> to continue.\n"
	fi
fi
