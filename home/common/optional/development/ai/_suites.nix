{optional, ...}: {
  ai.home = with optional.home.development.ai; [ai-usagebar claude-code code-assistant-profiles codex core opencode t3code tmux-agent-sidebar];
}
