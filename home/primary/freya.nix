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
    (map (f: ./common/optional/${f}) [
      "development/aws.nix"
      "stylix.nix"
      "work.nix"
    ])

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        # Helper Scripts
        # "helper-scripts"
        "helper-scripts"

        # Browsers
        "browsers"

        # Communication
        "comms"
        "librepods.nix"

        # Development
        "development"
        "development/ide"
        "development/ide/vscode"
        # "development/ide/vscode/server.nix"
        # "development/ide/jetbrains-remote.nix"
        # "development/jupyter-notebook.nix"
        # "development/virtualization/nixos-shell.nix"
        "development/ai"
        "development/postman.nix"
        "development/gcloud.nix"
        "development/gitlab.nix"
        "development/aws.nix"
        "development/virtualization"
        "development/virtualization/lens.nix"
        "development/virtualization/kubernetes"
        # "development/ai/litellm-proxy.nix"

        "development/languages/java.nix"
        "development/languages/node.nix"
        "development/languages/rust.nix"
        "development/tilt.nix"
        "development/grpc.nix"
        "secrets/buf.nix"
        "development/terraform.nix"
        "development/bootdev.nix"
        "development/nomad.nix"

        # Gaming
        "gaming/minecraft"
        "gaming/heroic.nix"
        "gaming/r2modman.nix"
        "gaming/bakkesmod.nix"
        "gaming/nitrox.nix"

        # Ghostty (Terminal)
        "ghostty"

        # Media
        "media"
        "media/spicetify.nix"
        "media/davinci-resolve.nix"
        # "media/tidal.nix"

        # Tools
        # "tools/gromit-mpx.nix"
        "tools/wayscriber.nix"
        "tools/freecad.nix"
        "tools/obsidian.nix"

        # NixOS Specific
        # "nixos/desktops/plasma6"
        "nixos/desktops/hyprland"
        "nixos/desktops/hyprland/common/software-dimming"
        "nixos/desktops/hyprland/nvidia.nix"
        "nixos/desktops/hyprland/sunshine.nix"
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
      ])
    ))
  ];

  home.file."Videos/Movies".source = config.lib.file.mkOutOfStoreSymlink "/mnt/videos";

  stylix.image = lib.mkForce (pkgs.runCommand "freya-black-wallpaper.png" {} ''
    ${lib.getExe pkgs.imagemagick} -size 3840x2160 xc:black $out
  '');

  programs.noctalia-shell.settings.bar = {
    displayMode = "auto_hide";
    autoHideDelay = 500;
    autoShowDelay = 150;
  };

  # services.safeeyes.enable = true;

  #
  # ========== Workspaces & App Placement ==========
  #
  # programs.niri.settings = {
  #   workspaces = {
  #     "01-browser" = {
  #       name = "browser";
  #       open-on-output = "DP-1";
  #     };
  #     "02-dev" = {
  #       name = "dev";
  #       open-on-output = "DP-3";
  #     };
  #     "03-chat" = {
  #       name = "chat";
  #       open-on-output = "DP-2";
  #     };
  #   };

  #   window-rules = [
  #     {
  #       matches = [{app-id = "^zen(-beta)?$";}];
  #       open-on-workspace = "browser";
  #     }
  #     {
  #       matches = [{app-id = "^code(-url-handler)?$";}];
  #       open-on-workspace = "dev";
  #     }
  #     {
  #       matches = [{app-id = "^Slack$";}];
  #       open-on-workspace = "chat";
  #     }
  #     {
  #       matches = [{app-id = "^(discord|legcord)$";}];
  #       open-on-workspace = "chat";
  #     }
  #   ];
  # };

  #
  # ========== Host-specific Monitor Spec ==========
  #
  # --------
  # | eDP-1 |
  # | 2560x1600@240Hz |
  # | Samsung built-in |
  # --------
  defaultMonitor.enable = false;

  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "workspace 3 silent, match:class ^(Slack)$"
      "workspace 3 silent, match:title Legcord$"
      "workspace 2 silent, match:class ^(zen(-beta)?)$"
    ];
  };

  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs.slack}/share/applications/slack.desktop"
      "${pkgs.discord-legcord}/share/applications/legcord.desktop"
      "${config.programs.zen-browser.package}/share/applications/zen-beta.desktop"
      "${pkgs._1password-gui}/share/applications/1password.desktop"
      "${config.programs.spicetify.spicedSpotify}/share/applications/spotify.desktop"
    ];
  };

  monitors = [
    {
      name = "eDP-1";
      width = 2560;
      height = 1600;
      refreshRate = 240;
      x = 0;
      y = 0;
      scale = 1.25;
      primary = true;
      oled = true;
      vrr = "on";
      hdr = true;
      bitdepth = 10;
    }
  ];
}
