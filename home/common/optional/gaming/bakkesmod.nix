# BakkesMod configuration
{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.bakkesmod-nix.homeManagerModules.default
  ];

  # To use: add 'bakkes-launcher %command%' to Rocket League Steam launch options
  programs.bakkesmod = {
    enable = true;
    plugins = with pkgs.bakkesmod-plugins; [
      ingamerank
      rocketstats
      {
        plugin = deja-vu-player-tracking;
        extraConfig = ''
          // Position
          cl_dejavu_toggle_with_scoreboard "1"
          cl_dejavu_xpos "0.9"
          cl_dejavu_ypos "0.0"
          cl_dejavu_width "0.15"
          cl_dejavu_scale "1.5"

          // Styling - clean dark theme
          cl_dejavu_alpha "0.85"
          cl_dejavu_background "1"
          cl_dejavu_background_color "(20, 20, 25, 200)"
          cl_dejavu_borders "1"
          cl_dejavu_border_color "(80, 80, 90, 180)"
          cl_dejavu_text_color "(240, 240, 245, 255)"

          // Display options
          cl_dejavu_show_metcount "1"
          cl_dejavu_show_record "1"
        '';
      }
    ];
    config = {
      gui.scale = 1.2;
      ranked = {
        showRanks = true;
        showRanksCasual = true;
        showRanksCasualMenu = true;
        showRanksMenu = true;
      };
    };
  };
}
