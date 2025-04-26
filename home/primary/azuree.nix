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
    common/optional/secrets
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
    common/optional/development/virtualization
    common/optional/development/virtualization/lens.nix
  ];

  services.easyeffects = {
    enable = true;
    # preset = {
    # input = {
    #   "input" = {
    #     blocklist = [];
    #     plugins_order = [
    #       "stereo_tools#0"
    #       "rnnoise#0"
    #     ];
    #     plugins = {
    #       "rnnoise#0" = {
    #         bypass = false;
    #         "enable-vad" = true;
    #         "input-gain" = 0.0;
    #         "model-name" = "";
    #         "output-gain" = 0.0;
    #         release = 20.0;
    #         "vad-thres" = 50.0;
    #         wet = 0.0;
    #       };
    #       "stereo_tools#0" = {
    #         "balance-in" = 0.0;
    #         "balance-out" = 0.0;
    #         bypass = false;
    #         delay = 0.0;
    #         "input-gain" = 0.0;
    #         "middle-level" = 0.0;
    #         "middle-panorama" = 0.0;
    #         mode = "LR > RR (Mono Right Channel)";
    #         mutel = false;
    #         muter = false;
    #         "output-gain" = 0.0;
    #         phasel = false;
    #         phaser = false;
    #         "sc-level" = 1.0;
    #         "side-balance" = 0.0;
    #         "side-level" = 0.0;
    #         softclip = false;
    #         "stereo-base" = 0.0;
    #         "stereo-phase" = 0.0;
    #       };
    #     };
    #   };
    # };
    # };
  };

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
