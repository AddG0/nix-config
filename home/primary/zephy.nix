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
      "work.nix"
    ])

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        # Helper Scripts
        # "helper-scripts"
        "helper-scripts"

        # Browsers
        "browsers"

        # Communication
        "comms"

        # Development
        "development"
        "development/ide"
        "development/ide/vscode"
        "development/ide/vscode/server.nix"
        "development/ide/jetbrains-remote.nix"
        "development/jupyter-notebook.nix"
        "development/virtualization/nixos-shell.nix"
        "development/ai"
        "development/postman.nix"
        "development/gcloud.nix"
        "development/aws.nix"
        # "development/virtualization"
        "development/virtualization/lens.nix"
        "development/virtualization/kubernetes"
        "development/ai/litellm-proxy.nix"

        "development/languages/java.nix"
        "development/languages/node.nix"
        "development/grpc.nix"
        "secrets/buf.nix"
        "development/terraform.nix"

        # Gaming
        "gaming/minecraft"
        "gaming/heroic.nix"
        "gaming/r2modman.nix"
        "gaming/bakkesmod.nix"

        # Ghostty (Terminal)
        "ghostty"

        # Media
        "media"
        "media/spicetify.nix"
        # "media/tidal.nix"

        # Tools
        "tools"
        "tools/gromit-mpx.nix"

        # NixOS Specific
        "nixos/desktops/plasma6"
        "media/vlc.nix"

        # Remote Desktop
        # "remote-desktop/rustdesk.nix"
        # "remote-desktop/mouseshare/lan-mouse.nix"

        # Secrets
        "secrets"
        "secrets/kubeconfig.nix"
        "secrets/ai.nix"
        "secrets/elevenlabs.nix"
        "secrets/1password-ssh.nix"
        # "secrets/1password-ssh.nix"
      ])
    ))
  ];

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
      width = 2560;
      height = 1600;
      refreshRate = 165;
      x = 555;
      y = 0;
      vrr = "on";
      primary = true;
    }
    {
      name = "desc:BOE 0x0A68";
      width = 3840;
      height = 1100;
      refreshRate = 60;
      x = 0;
      y = 1600;
    }
  ];
}
