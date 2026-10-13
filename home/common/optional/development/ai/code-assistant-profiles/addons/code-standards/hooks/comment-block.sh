#!/usr/bin/env bash
set -euo pipefail

payload=$(cat)
file=$(jq -r '.tool_input.file_path // ""' <<<"$payload")

# Prose is allowed to run long; the rule governs code.
case "$file" in
"" | *.md | *.mdx | *.txt | *.rst | *.adoc) exit 0 ;;
esac

# `#include` and shebangs are not comments, so `#` must be followed by space.
max_comment_run() {
  awk '
    { line = $0; sub(/^[[:space:]]+/, "", line)
      if (line ~ /^(#[ \t]|\/\/|\/\*|\*[ \t\/]|--[ \t])/) { if (++run > max) max = run }
      else run = 0 }
    END { print max + 0 }
  '
}

new_run=$(jq -r '.tool_input.new_string // ""' <<<"$payload" | max_comment_run)
old_run=$(jq -r '.tool_input.old_string // ""' <<<"$payload" | max_comment_run)

# Comparing against the replaced text keeps an untouched header the edit merely
# spanned from firing this.
if ((new_run >= 3 && new_run > old_run)); then
  jq -n --arg n "$new_run" --arg f "$file" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("Comments rule: that edit put a \($n)-line comment block in \($f). A real why fits on one line — compress it or delete it now, before moving on.")
    }
  }'
fi
