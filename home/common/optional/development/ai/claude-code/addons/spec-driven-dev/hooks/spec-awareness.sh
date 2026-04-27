#!/usr/bin/env bash
# UserPromptSubmit hook: inject active spec context and skill evaluation
# Fires before every prompt. stdout is added as context to Claude.

INPUT=$(cat) || true
[ -n "$INPUT" ] || exit 0

PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty') || true
CWD=$(echo "$INPUT" | jq -r '.cwd // empty') || true
CWD="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
SPEC_DIR="$CWD/.sdd/specs"

# Check for active specs with incomplete tasks
# Task-level checkboxes match: "- [ ] ### Task" or "- [x] ### Task"
if [ -d "$SPEC_DIR" ]; then
	ACTIVE=""
	for tasks_file in "$SPEC_DIR"/*/tasks.md; do
		[ -f "$tasks_file" ] || continue
		SPEC_NAME=$(basename "$(dirname "$tasks_file")")
		TOTAL=$(grep -cE '^- \[.\] ### Task' "$tasks_file" 2>/dev/null || echo 0)
		DONE=$(grep -cE '^- \[x\] ### Task' "$tasks_file" 2>/dev/null || echo 0)
		REMAINING=$((TOTAL - DONE))
		if [ "$REMAINING" -gt 0 ]; then
			NEXT=$(grep -m1 '^- \[ \] ### Task' "$tasks_file" | sed 's/^- \[ \] ### //' | cut -c1-60 || true)
			ACTIVE="${ACTIVE}  ${SPEC_NAME}: ${DONE}/${TOTAL} tasks complete (next: ${NEXT})"$'\n'
		fi
	done

	if [ -n "$ACTIVE" ]; then
		printf "ACTIVE SPECS:\n%s" "$ACTIVE"
		printf "Use /spec-status for details or /spec-execute <name> <task#> to continue.\n"
	fi
fi

# Detect implementation intent without a spec (narrow matching)
if echo "$PROMPT" | grep -qiE '\b(add feature|new feature|implement feature|build feature)\b'; then
	if [ ! -d "$SPEC_DIR" ] || [ -z "$(ls -A "$SPEC_DIR" 2>/dev/null)" ]; then
		printf "\nNOTE: No specs found. For non-trivial features, consider /interview or /spec-create first.\n"
	fi
fi
