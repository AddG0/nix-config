{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = lib.flatten [
    inputs.stylix.homeModules.stylix
    ./common/core
    (map (f: ./common/optional/${f}) [
      "development/aws.nix"
    ])

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "helper-scripts"

        "development/jupyter-notebook.nix"
        "development/ai"
        "development/virtualization/kubernetes"
        "development/virtualization/lens.nix"
        "development/ide.nix"
        "development/gcloud.nix"
        "development/terraform.nix"
        "development/postman.nix"
        "development"

        "secrets"
        "secrets/1password-ssh.nix"
        # "secrets/kubeconfig.nix"

        "nixos/desktops/plasma6"
        "browsers"

        "gaming/minecraft.nix"
        "gaming/heroic.nix"
        "gaming/bakkesmod.nix"
        "gaming"

        "comms"
        "ghostty"
        "media/spicetify.nix"
        "media/tidal.nix"
        "media"
        "nixos/vlc.nix"
        # "remote-desktop/rustdesk.nix"
      ])
    ))
  ];

  programs.btop.enable = lib.mkForce true;

  programs.plasma.input.mice = [
    {
      enable = true;
      name = "ASUE140F:00 04F3:31F7 Mouse";
      vendorId = "04F3";
      productId = "31F7";
      accelerationProfile = "none";
      naturalScroll = false;
      scrollSpeed = 0.2;
    }
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
    enable = false;
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
