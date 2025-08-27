{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true; # better than native direnv nix functionality - https://github.com/nix-community/nix-direnv
    sops-direnv.enable = true;
    lastpass.enable = true;
    onepassword.enable = true;
    silent = true;
  };

  home.packages = with pkgs; [
    devenv
  ];
}
