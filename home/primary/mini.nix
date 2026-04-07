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
      #  "nixos/services/rclone.nix"
      "stylix.nix" # using work rice stylix instead
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
        "development/gitlab.nix"
        "development/aws.nix"
        # "development/virtualization"
        "development/virtualization/lens.nix"
        "development/virtualization/kubernetes"
        "development/ai/litellm-proxy.nix"

        "development/languages/java.nix"
        "development/languages/node.nix"
        "development/languages/rust.nix"
        "development/tilt.nix"
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
        # "tools/gromit-mpx.nix"
        "tools/wayscriber.nix"

        # NixOS Specific
        # "nixos/desktops/plasma6"
        "nixos/desktops/hyprland/personal"
        # "nixos/desktops/hyprland/nvidia.nix"
        # "nixos/desktops/hyprland/sunshine.nix"
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

  programs.librepods.enable = true;

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
  #  -----------   -----------
  # | HDMI-A-1  | |   DP-3   |
  # | Samsung   | | Samsung  |
  # | U32J59x   | | U32J59x  |
  #  -----------   -----------
  defaultMonitor.enable = false;

  wayland.windowManager.hyprland.settings = {
    workspace = [
      "1, monitor:DP-3, default:true"
      "2, monitor:HDMI-A-1, default:true"
    ];

    # Mini keyboard has no Print Screen key — remap screenshots to Home
    bind = [
      "SUPER,Home,exec,${pkgs.hyprshot}/bin/hyprshot -m region"
    ];
  };

  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs.slack}/share/applications/slack.desktop"
      "${pkgs.discord-legcord}/share/applications/legcord.desktop"
      "${config.programs.zen-browser.package}/share/applications/zen-beta.desktop"
      "${pkgs._1password-gui}/share/applications/1password.desktop"
    ];
  };

  monitors = [
    {
      name = "HDMI-A-1";
      width = 3840;
      height = 2160;
      refreshRate = 60;
      x = 0;
      y = 0;
    }
    {
      name = "DP-3";
      width = 3840;
      height = 2160;
      refreshRate = 60;
      x = 3840;
      y = 0;
      primary = true;
    }
  ];
}
