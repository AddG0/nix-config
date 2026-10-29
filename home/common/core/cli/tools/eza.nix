{lib, ...}: {
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

  # Without a tty, eza with no path reads paths from stdin (empty output or a hang), and agent shells source .zshrc that way.
  programs.zsh.initContent = lib.mkAfter ''
    [[ -t 0 ]] || unalias ls ll la lt lla eza 2>/dev/null
  '';
}
