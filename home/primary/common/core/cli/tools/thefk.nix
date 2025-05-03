{pkgs, ...}: {
  programs.thefuck = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableInstantMode = true;
  };

  home.shellAliases = {
    fk = "fuck";
  };
}
