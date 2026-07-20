# Loads tmux-agent-sidebar as a Claude Code plugin (--plugin-dir) so its
# hooks/hooks.json feeds agent state to the tmux sidebar (home/common/core/cli/tmux).
# Self-contained: delete this file, its import in ./default.nix, and the package
# in pkgs/tmux-plugins to remove the integration.
{pkgs, ...}: {
  programs.claude-code-profiles.baseConfig.pluginDirs = [
    "${pkgs.tmuxPlugins.tmux-agent-sidebar}/share/tmux-plugins/tmux-agent-sidebar"
  ];
}
