#!/usr/bin/env bash
# PreToolUse(AskUserQuestion): strip "(Recommended)", shuffle options, seal the pick for reveal-pick.sh.
# Any failure exits non-zero, which Claude Code treats as non-blocking: the original question is shown.

input=$(cat)
tool_use_id=$(jq -er '.tool_use_id' <<<"$input")
sealed="$XDG_RUNTIME_DIR/claude-blind-choices/$tool_use_id.json"

picks=$(jq -c '
  [.tool_input.questions[]
    | {label: (.header // .question)}
      + {pick: ([.options[] | select(.label | test("\\(recommended\\)\\s*$"; "i"))][0].label)}
    | select(.pick != null)
    | .pick |= sub("\\s*\\(recommended\\)\\s*$"; ""; "i")]
' <<<"$input")

[ "$picks" = "[]" ] && exit 0

perms=$(jq -r '.tool_input.questions[].options | length' <<<"$input" |
  while read -r n; do shuf -i "0-$((n - 1))" | jq -sc .; done | jq -sc .)

output=$(jq -c --argjson perms "$perms" '
  .tool_input
  | .questions |= [to_entries[] | .key as $i | .value
      | .options |= ([.[] | .label |= sub("\\s*\\(recommended\\)\\s*$"; ""; "i")] as $opts
          | [$perms[$i][] | $opts[.]])]
  | {hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "blind-choices: pick hidden until answered",
      updatedInput: .
    }}
' <<<"$input")

mkdir -p "$(dirname "$sealed")"
printf '%s\n' "$picks" >"$sealed"
printf '%s\n' "$output"
