# The override is the only way past git-push-guard, so it's what needs a human.
cmd=$(jq -r '.tool_input.command // ""')
if grep -q ALLOW_GIT_PUSH <<<"$cmd"; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"ALLOW_GIT_PUSH (git push)"}}'
fi
