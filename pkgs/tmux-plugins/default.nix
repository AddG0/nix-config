# tmux plugins not packaged in nixpkgs — merged into pkgs.tmuxPlugins by the overlay
pkgs: {
  tmux-agent-sidebar = pkgs.callPackage ./tmux-agent-sidebar {};
}
