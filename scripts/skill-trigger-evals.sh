#!/usr/bin/env bash
# Checks which skill a Claude Code profile reaches for, one headless run per case.
# Usage: skill-trigger-evals.sh [profile] [cases.tsv]   (MODEL=… to override the model)
set -euo pipefail

profile="${1:-default}"
evals_dir="$(dirname "$0")/../home/common/optional/development/ai/code-assistant-profiles/evals"
# default's cases are skill-triggers.tsv; any other profile's are skill-triggers.<profile>.tsv.
if [ "$profile" = default ]; then default_cases="$evals_dir/skill-triggers.tsv"; else default_cases="$evals_dir/skill-triggers.$profile.tsv"; fi
cases="${2:-$default_cases}"
per_case_timeout="${TIMEOUT:-180}"
# The first few tool calls show the routing decision; later ones are just the skill running.
max_tool_calls=4

command -v jq >/dev/null || {
  echo "skill-trigger-evals: jq is required" >&2
  exit 2
}
[ -f "$cases" ] || {
  echo "skill-trigger-evals: cases file not found: $cases" >&2
  exit 2
}

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

# Pulls the first Skill call out of stream-json; prints `none` if it doesn't come within max_tool_calls.
first_skill() {
  jq --unbuffered -r '
    select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")
    | if .name == "Skill" then "skill:" + (.input.skill // "?") else "tool:" + .name end' |
    awk -v max="$max_tool_calls" '
      /^skill:/ { sub(/^skill:/, ""); print; found = 1; exit }
      { if (++n >= max) { print "none-within-window"; found = 1; exit } }
      END { if (!found) print "none" }'
}

pass=0 fail=0
while IFS=$'\t' read -r expect prompt; do
  [[ -z $expect || $expect == \#* ]] && continue

  model_args=()
  [ -n "${MODEL:-}" ] && model_args=(--model "$MODEL")

  # Read-only tool set: a mis-trigger must not be able to change anything.
  stream="$sandbox/run.jsonl"
  got=$(cd "$sandbox" && timeout "$per_case_timeout" claude -P "$profile" -p "$prompt" \
    --output-format stream-json --verbose --no-session-persistence \
    --disallowedTools Bash Edit Write NotebookEdit Agent WebFetch WebSearch \
    "${model_args[@]}" 2>/dev/null | tee "$stream" | first_skill) || true

  # A run that never got going (not logged in, timeout) also calls no skill; don't score it as `none`.
  if [ "${got:-none}" = none ]; then
    run_error=$(jq -r 'select(.type == "result") | if .is_error then .result else "ok" end' "$stream" 2>/dev/null | tail -1)
    if [ "$run_error" != ok ]; then
      fail=$((fail + 1))
      printf 'ERROR %-28s %s — %s\n' "$expect" "${run_error:-no result (timed out after ${per_case_timeout}s?)}" "$prompt"
      continue
    fi
  fi
  [ "${got:-none}" = none-within-window ] && got=none
  got="${got:-none}"

  case "$expect" in
  !*) ok=$([ "$got" != "${expect#!}" ] && echo 1 || echo 0) ;;
  *) ok=$([ "$got" == "$expect" ] && echo 1 || echo 0) ;;
  esac

  if [ "$ok" = 1 ]; then
    pass=$((pass + 1))
    printf 'PASS  %-28s %s\n' "$expect" "$prompt"
  else
    fail=$((fail + 1))
    printf 'FAIL  %-28s got=%-24s %s\n' "$expect" "$got" "$prompt"
  fi
done <"$cases"

echo "profile=$profile pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
