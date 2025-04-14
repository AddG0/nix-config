{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.stylix.homeManagerModules.stylix

    #################### Required Configs ####################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/helper-scripts
    common/optional/jupyter-notebook
    common/optional/nixos/desktops/hyprland # default is hyprland
    common/optional/browsers
    common/optional/development/ide.nix
    common/optional/secrets/sops.nix
    common/optional/secrets/kubeconfig.nix
    common/optional/gaming/minecraft.nix
    common/optional/gaming/steam.nix
    common/optional/comms
    common/optional/ghostty
    common/optional/nixos/1password.nix
    common/optional/development/aws.nix
    common/optional/nixos/gpg-agent.nix
    common/optional/media/spicetify.nix
    common/optional/media/tidal.nix
    common/optional/media
    # common/optional/remote-desktop/rustdesk.nix
  ];

  # modules.desktop.hyprland = {
  #   enable = true;
  #   nvidia = true;
  #   settings = {
  #     workspace = [
  #       "1,monitor:desc:AU Optronics 0x8E9D"
  #     ];
  #   };
  # };

  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url = "https://unsplash.com/photos/3l3RwQdHRHg/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzM2NTE4NDQ2fA&force=true";
      sha256 = "LtdnBAxruHKYE/NycsA614lL6qbGBlkrlj3EPNZ/phU=";
    };
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    cursor = {
      package = pkgs.catppuccin-cursors.mochaDark;
      name = "Catppuccin-Mocha-Dark";
      size = 24; # or 16, 20, 32, etc. — whatever looks right on your display
    };
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 0.8;
    };
    polarity = "dark";
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
      resolution = "2560x1600@165.04";
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
