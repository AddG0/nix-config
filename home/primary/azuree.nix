{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = lib.flatten [
    inputs.stylix.homeModules.stylix
    ./common/core

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        # "helper-scripts"
        # "development/jupyter-notebook.nix"
        "browsers"
        "development/ide.nix"
        # "secrets"
        # "secrets/kubeconfig.nix"
        "gaming/minecraft.nix"
        "gaming/heroic.nix"
        "comms"
        "ghostty"
        "media/spicetify.nix"
        "media/tidal.nix"
        "media"
        "nixos/desktops/plasma6"
        # "remote-desktop/rustdesk.nix"
        # "development/virtualization"
        # "development/virtualization/lens.nix"
        "development/gcloud.nix"
        "nixos/vlc.nix"
        # "remote-desktop/mouseshare/lan-mouse.nix"
        # "development/ai"
        "development/postman.nix"
        "helper-scripts"
      ])
    ))
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
  services.safeeyes.enable = true;

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
