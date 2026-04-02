#!/usr/bin/env bash
# PreToolUse hook (Edit|Write): protect steering and spec files from accidental modification.
# These files should only be modified through their respective skills.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Protect steering docs — only /spec-steering-setup should modify these
if [[ "$FILE_PATH" == *".claude/steering/"* ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"This is a steering document (.claude/steering/). Use /spec-steering-setup to modify it. Allow if you are sure."}}'
  exit 0
fi

exit 0
