{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.bakkesmod-nix.homeManagerModules.default
  ];

  programs.bakkesmod = {
    enable = true;
    # Custom maps render untextured without the UDK editor packages.
    workshopTextures.enable = true;
    plugins = with pkgs.bakkesmod-plugins; [
      better-steam-workshop-loader
      # Hosts a joinable local/LAN match on any loaded map.
      rocket-plugin
      # Support plugin for multiplayer workshop maps and plugins.
      netcode-plugin
      # Spawns a bot in freeplay to take kickoffs against you.
      kickoff-practice
      # Kickoffs against a recording of your own inputs.
      better-kickoff-training
      # Scripted inputs for custom shots and speedruns.
      tas-plugin
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

  programs.rlbot.enable = true;

  # Match on title — the injector shares Rocket League's class (steam_app_252950).
  wayland.windowManager.hyprland.settings.windowrule = [
    "float on, match:title ^(BakkesModInjectorCpp)$"
    "workspace special silent, match:title ^(BakkesModInjectorCpp)$"
  ];
}
