# BakkesMod configuration
{pkgs, ...}: {
  # To use: add 'bakkes-launcher %command%' to Rocket League Steam launch options
  programs.bakkesmod = {
    enable = true;
    plugins = [
      pkgs.bakkesmod-plugins.ingamerank
    ];
    config = {
      gui.scale = 1.5;
      ranked = {
        showRanks = true;
        showRanksCasual = true;
        showRanksCasualMenu = true;
        showRanksMenu = true;
      };
    };
  };
}
