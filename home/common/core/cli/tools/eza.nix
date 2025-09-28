{
  # A modern replacement for ‘ls’
  programs.eza = {
    enable = true;
    # do not enable aliases in nushell!
    enableNushellIntegration = false;
    enableZshIntegration = true;
    enableBashIntegration = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--color=always"
      "--long"
    ];
  };
}
