#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): track changes to spec documents.
# Appends timestamped entry to changelog.md within the spec directory.

INPUT=$(cat) || true
[ -n "$INPUT" ] || exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty') || true
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty') || true

[ -n "$FILE_PATH" ] || exit 0

# Only track changes to spec documents (not tasks.md checkbox toggles)
if [[ $FILE_PATH == *".sdd/specs/"*"/requirements.md" ]] ||
	[[ $FILE_PATH == *".sdd/specs/"*"/design.md" ]]; then

	SPEC_DIR=$(dirname "$FILE_PATH")
	CHANGELOG="$SPEC_DIR/changelog.md"
	FILENAME=$(basename "$FILE_PATH")
	TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M UTC')

	# Create changelog if it doesn't exist
	if [ ! -f "$CHANGELOG" ]; then
		printf "# Spec Changelog\n\n" >"$CHANGELOG" || exit 0
	fi

	# Append entry
	printf "- **%s** — %s modified via %s\n" "$TIMESTAMP" "$FILENAME" "$TOOL_NAME" >>"$CHANGELOG" || exit 0
fi

exit 0
