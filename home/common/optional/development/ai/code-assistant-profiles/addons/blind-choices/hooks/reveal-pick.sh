#!/usr/bin/env bash
# PostToolUse(AskUserQuestion): show the user the pick hide-pick.sh sealed, and hold Claude to it.

input=$(cat)
tool_use_id=$(jq -er '.tool_use_id' <<<"$input")
sealed="$XDG_RUNTIME_DIR/claude-blind-choices/$tool_use_id.json"

[ -f "$sealed" ] || exit 0

jq -c '([.[] | "\(.label): \(.pick)"] | join("; ")) as $picks | {
  systemMessage: "Claude'\''s pick (sealed before you answered): \($picks)",
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "blind-choices: the user answered without seeing your pick (\($picks)). Where their answer differs, give one line for your pick and one line against it, then follow their answer. Do not change your pick to match theirs."
  }
}' "$sealed"
rm -f "$sealed"
