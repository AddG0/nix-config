{pkgs, ...}: {
  programs.pay-respects = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  home.shellAliases = {
    fk = "f";
  };
}
