#!/usr/bin/env bash
# PreToolUse hook (Edit|Write): protect steering docs and spec requirements/design
# from accidental modification DURING IMPLEMENTATION (when tasks have started).
# Does NOT trigger during spec creation or before any tasks are executed.

INPUT=$(cat) || true
[ -n "$INPUT" ] || exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty') || true
[ -n "$FILE_PATH" ] || exit 0

# Protect steering docs — always ask
if [[ $FILE_PATH == *".claude/steering/"* ]]; then
	echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"This is a steering document (.claude/steering/). Use /spec-steering-setup to modify it. Allow if you are sure."}}'
	exit 0
fi

# Protect requirements.md and design.md — but ONLY if implementation has started
# (at least one task marked [x] in that spec's tasks.md)
if [[ $FILE_PATH == *".claude/specs/"*"/requirements.md" ]] || [[ $FILE_PATH == *".claude/specs/"*"/design.md" ]]; then
	SPEC_DIR=$(dirname "$FILE_PATH")
	TASKS_FILE="$SPEC_DIR/tasks.md"

	# If no tasks.md exists, we're still in spec creation — allow freely
	[ -f "$TASKS_FILE" ] || exit 0

	# If no tasks have been completed yet, we're still in planning — allow freely
	if grep -qE '^\- \[x\] ### Task' "$TASKS_FILE" 2>/dev/null; then
		echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Implementation is underway — changing requirements or design may cause spec drift. Use /spec-create to modify specs intentionally. Allow if you are sure."}}'
		exit 0
	fi
fi

exit 0
