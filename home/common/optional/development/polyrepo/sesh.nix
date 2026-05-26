_: {
  programs.sesh = {
    enable = true;
    enableAlias = false; # we use tmux binding, not a shell alias
    enableTmuxIntegration = true;
    tmuxKey = "T";
    icons = true;
    settings = {};
  };
}
