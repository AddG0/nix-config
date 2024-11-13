{ pkgs, ... }: {
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true; # better than native direnv nix functionality - https://github.com/nix-community/nix-direnv
  };

  programs.zsh.initExtra = ''
    export PATH=${pkgs.direnv}/bin:$PATH
  '';
}
