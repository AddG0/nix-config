#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): track changes to spec documents.
# Appends timestamped entry to changelog.md within the spec directory.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only track changes to spec documents (not tasks.md checkbox toggles)
if [[ "$FILE_PATH" == *".claude/specs/"*"/requirements.md" ]] || \
   [[ "$FILE_PATH" == *".claude/specs/"*"/design.md" ]]; then

  SPEC_DIR=$(dirname "$FILE_PATH")
  CHANGELOG="$SPEC_DIR/changelog.md"
  FILENAME=$(basename "$FILE_PATH")
  TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M UTC')

  # Create changelog if it doesn't exist
  if [ ! -f "$CHANGELOG" ]; then
    printf "# Spec Changelog\n\n" > "$CHANGELOG"
  fi

  # Append entry
  printf "- **%s** — %s modified via %s\n" "$TIMESTAMP" "$FILENAME" "$TOOL_NAME" >> "$CHANGELOG"
fi

exit 0
