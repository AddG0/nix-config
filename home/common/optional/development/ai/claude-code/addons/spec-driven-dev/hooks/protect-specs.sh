#!/usr/bin/env bash
# PreToolUse hook (Edit|Write): warn when editing spec requirements or design docs.
# tasks.md is allowed (for marking completion). requirements.md and design.md are protected.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Protect requirements and design docs from accidental mutation during implementation
if [[ "$FILE_PATH" == *".claude/specs/"*"/requirements.md" ]] || [[ "$FILE_PATH" == *".claude/specs/"*"/design.md" ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"This is a spec document. Changing requirements or design during implementation may cause spec drift. Use /spec-create to modify specs intentionally. Allow if you are sure."}}'
  exit 0
fi

exit 0
