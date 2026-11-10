# SessionStart: snapshot the tree this session starts from, so the gate knows what the session changed.
# Uses repo_root, baseline_file and record_baseline from state.sh, which hooks.nix prepends.

input=$(cat)
session=$(jq -er '.session_id' <<<"$input")
cwd=$(jq -er '.cwd' <<<"$input")
source=$(jq -r '.source // "startup"' <<<"$input")

root=$(repo_root "$cwd") || {
  [ $? = 1 ] && exit 0
  exit 1
}
# A resumed or compacted session keeps where it began.
if [ -s "$(baseline_file "$root" "$session")" ]; then
  exit 0
fi
record_baseline "$root" "$session"
if [ "$source" = resume ] || [ "$source" = compact ]; then
  jq -nc --arg root "$root" \
    '{systemMessage: "Self-documenting gate: no baseline survived for this session in \($root), so its changes count from now."}'
fi
