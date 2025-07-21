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
    # common/optional/helper-scripts
    # common/optional/jupyter-notebook
    common/optional/browsers
    common/optional/development/ide.nix
    # common/optional/secrets
    # common/optional/secrets/kubeconfig.nix
    common/optional/gaming/minecraft.nix
    common/optional/gaming/steam.nix
    common/optional/comms
    common/optional/ghostty
    common/optional/nixos/1password.nix
    # common/optional/development/aws.nix
    common/optional/nixos/gpg-agent.nix
    common/optional/media/spicetify.nix
    common/optional/media/tidal.nix
    common/optional/media
    common/optional/nixos/desktops/plasma6
    # common/optional/remote-desktop/rustdesk.nix
    # common/optional/development/virtualization
    # common/optional/development/virtualization/lens.nix
    common/optional/nixos/vlc.nix
    # common/optional/remote-desktop/mouseshare/lan-mouse.nix
    # common/optional/development/postman.nix
    common/optional/development/tools.nix
  ];

  home.file."Videos/Movies".source = config.lib.file.mkOutOfStoreSymlink "/mnt/videos";

  stylix = {
    enable = false;
    image = pkgs.fetchurl {
      url = "https://unsplash.com/photos/3l3RwQdHRHg/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzM2NTE4NDQ2fA&force=true";
      sha256 = "LtdnBAxruHKYE/NycsA614lL6qbGBlkrlj3EPNZ/phU=";
    };
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Original-Classic";
      size = 24; # adjust to your display
    };
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 0.8;
    };
    polarity = "dark";
  };

  programs.btop.enable = lib.mkForce true;

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
