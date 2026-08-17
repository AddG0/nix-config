{pkgs, ...}: {
  # Claude Code integration
  programs.claude-code-profiles.baseConfig.pluginDirs = [
    "${pkgs.tmuxPlugins.tmux-agent-sidebar}/share/tmux-plugins/tmux-agent-sidebar"
  ];

  # OpenCode integration
  home.file.".config/opencode/plugins/tmux-agent-sidebar.js".source = "${pkgs.tmuxPlugins.tmux-agent-sidebar}/share/tmux-plugins/tmux-agent-sidebar/.opencode/plugins/tmux-agent-sidebar.js";
}
