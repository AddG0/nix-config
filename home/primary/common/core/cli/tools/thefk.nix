{pkgs, ...}: {
  programs.thefuck = {
    # TODO: make this work
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    # enableInstantMode = true;
  };

  home.shellAliases = {
    fk = "fuck";
  };
}
