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
      "nixos/services/rclone.nix"
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
        # "tools/gromit-mpx.nix"
        "tools/wayscriber.nix"

        # NixOS Specific
        # "nixos/desktops/plasma6"
        "nixos/desktops/hyprland"
        "nixos/desktops/hyprland/nvidia.nix"
        "media/vlc.nix"

        # Remote Desktop
        "remote-desktop/rustdesk.nix"
        # "remote-desktop/mouseshare/lan-mouse.nix"

        # Secrets
        "secrets"
        "secrets/kubeconfig.nix"
        "secrets/ai.nix"
        "secrets/elevenlabs.nix"
        # "secrets/1password-ssh.nix"
      ])
    ))
  ];

  home.file."Videos/Movies".source = config.lib.file.mkOutOfStoreSymlink "/mnt/videos";

  services.safeeyes.enable = true;

  services.gpu-screen-recorder = {
    enable = true;
    matchMonitorName = "LG ULTRAGEAR";
    codec = "av1";
  };

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
  #  ------   ------
  # | DP-1 | | DP-3 | ----
  # | ASUS | |  LG  | |DP-2|
  #  ------   ------  |(rot)|
  #                    ----
  defaultMonitor.enable = false;

  wayland.windowManager.hyprland.settings = {
    workspace = [
      "1, monitor:DP-3, default:true"
      "2, monitor:DP-1, default:true"
      "3, monitor:DP-2, default:true"
    ];
    windowrule = [
      "workspace 3 silent, match:class ^(Slack)$"
      "workspace 3 silent, match:class ^(legcord)$"
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
    ];
  };

  monitors = [
    {
      name = "DP-1";
      width = 3840;
      height = 2160;
      refreshRate = 144;
      x = 0;
      y = 0;
      bitdepth = 10;
      hdr = true;
    }
    {
      name = "DP-3";
      width = 3840;
      height = 2160;
      refreshRate = 240;
      x = 3840;
      y = 0;
      primary = true;
      bitdepth = 10;
      hdr = true;
    }
    {
      name = "DP-2";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      transform = "270";
      x = 7680;
      y = 240; # bottom-aligned with DP-3 (2160 - 1920 = 240)
    }
  ];
}
