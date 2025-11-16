# BakkesMod configuration
{ pkgs, ... }: {
  programs.bakkesmod = {
    enable = true;
    plugins = [
      pkgs.bakkesmod-plugins.ingamerank
    ];
  };
}
