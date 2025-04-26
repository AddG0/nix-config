{
  pkgs,
  lib,
  ...
}: {
  programs.btop = {
    enable = true;
    settings = {
      color_theme = lib.mkDefault "catppuccin_mocha";
      theme_background = false; # make btop transparent
    };
  };
}
