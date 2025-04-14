{
  config,
  lib,
  ...
}: {
  imports = [
    #################### Required Configs ####################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/helper-scripts
    common/optional/jupyter-notebook
    common/optional/nixos/desktops/hyprland # default is hyprland
    common/optional/development/ide.nix
    common/optional/gaming/minecraft.nix
    common/optional/gaming/steam.nix
    common/optional/comms
    common/optional/browsers
    common/optional/ghostty
    common/optional/nixos/1password.nix
  ];

  home = {
    username = lib.mkDefault config.hostSpec.username;
    homeDirectory = lib.mkDefault config.hostSpec.home;
  };

  modules.desktop.hyprland = {
    enable = true;
    nvidia = true;
    settings = {
      workspace = [
        "1,monitor:desc:AU Optronics 0x8E9D"
      ];
    };
  };

  #
  # ========== Host-specific Monitor Spec ==========
  #
  # This uses the nix-config/modules/home/montiors.nix module which defaults to enabled.
  # Your nix-config/home-manger/<user>/common/optional/desktops/foo.nix WM config should parse and apply these values to it's monitor settings
  # If on hyprland, use `hyprctl monitors` to get monitor info.
  # https://wiki.hyprland.org/Configuring/Monitors/
  #           ------
  #        | HDMI-A-1 |
  #           ------
  #  ------   ------   ------
  # | DP-2 | | DP-1 | | DP-3 |
  #  ------   ------   ------
  monitors = [
    {
      name = "desc:AU Optronics 0x8E9D";
      use_nwg = true;
      width = 2560;
      height = 1600;
      resolution = "preferred";
      refreshRate = 165;
      x = 555;
      y = 0;
      vrr = 1;
      primary = true;
    }
    {
      name = "desc:BOE 0x0A68";
      width = 3840;
      height = 1100;
      refreshRate = 60;
      vrr = 0;
      x = 0;
      y = 1600;
      # workspace = "0";
    }
    {
      name = "";
      position = "auto";
      resolution = "preferred";
    }
  ];
}
