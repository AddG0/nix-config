{
  config,
  inputs,
  pkgs,
  lib,
  hostSpec,
  desktops,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix

    #################### Required Configs ####################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/nixos/desktops/hyprland
    common/optional/browsers
    common/optional/development/ide.nix
    common/optional/comms
    common/optional/ghostty
  ];


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
      name = "DP-1";
      use_nwg = false;
      width = 3440;
      height = 1440;
      # resolution = "2560x1600@165.04";
      refreshRate = 180;
      x = 3840;
      y = 218;
      vrr = 1;
      primary = true;
    }
    {
      name = "DP-2";
      width = 3840;
      height = 2160;
      refreshRate = 144;
      vrr = 0;
      x = 0;
      y = 0;
      # workspace = "0";
    }
    {
      name = "DP-3";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      transform = 3;
      vrr = 0;
      x = 7280;
      y = 0;
      # workspace = "0";
    }
    {
      name = "";
      position = "auto";
      resolution = "preferred";
    }
  ];
}