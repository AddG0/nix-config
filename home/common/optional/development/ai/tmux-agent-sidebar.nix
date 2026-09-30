{customPkgs, ...}: {
  # Claude Code integration
  programs.claude-code-profiles.baseConfig.pluginDirs = [
    "${customPkgs.tmux-plugins.tmux-agent-sidebar}/share/tmux-plugins/tmux-agent-sidebar"
  ];

  # OpenCode integration
  home.file.".config/opencode/plugins/tmux-agent-sidebar.js".source = "${customPkgs.tmux-plugins.tmux-agent-sidebar}/share/tmux-plugins/tmux-agent-sidebar/.opencode/plugins/tmux-agent-sidebar.js";
}
