# shellcheck shell=bash
# The override is the only way past git-push-guard, so it's what needs a human.
ask() {
  jq -nc --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
}
# Unreadable input asks too: a failing hook is non-blocking, so it would skip the prompt.
if ! cmd=$(jq -r '.tool_input.command // ""'); then
  ask "git-push-guard could not read the hook input"
elif grep -q ALLOW_GIT_PUSH <<<"$cmd"; then
  ask "ALLOW_GIT_PUSH (git push)"
fi
