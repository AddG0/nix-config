{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = lib.flatten [
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
        "mic-mute-sound.nix"

        # Development
        "development"
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
        "development/languages"
        "development/tilt.nix"
        "development/grpc.nix"
        "development/terraform.nix"
        "development/bootdev.nix"
        "development/nomad.nix"
        "secrets/buf.nix"

        # Gaming
        "gaming"
        "gaming/minecraft"
        "gaming/heroic.nix"
        "gaming/r2modman.nix"
        "gaming/nitrox.nix"
        "gaming/bigscreen-beyond.nix"

        # Ghostty (Terminal)
        "ghostty"

        # Media
        "media"
        "media/spicetify.nix"
        "media/davinci-resolve.nix"
        # "media/tidal.nix"

        # Tools
        "tools/wayscriber.nix"
        "tools/freecad.nix"
        "tools/obsidian.nix"
        "tools/krita.nix"

        # NixOS Specific
        # "nixos/desktops/plasma6"
        "nixos/desktops/hyprland"
        "nixos/desktops/hyprland/nvidia.nix"
        "nixos/desktops/hyprland/sunshine.nix"
        "nixos/desktops/hyprland/software-dimming.nix"
        "nixos/desktops/hyprland/wlcrosshair.nix"
        "nixos/services/gpu-screen-recorder.nix"
        "nixos/services/hass-agent.nix"
        "nixos/services/safeeyes"
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

  services.gpu-screen-recorder = {
    # Portal mode captures via xdg-desktop-portal, converting HDR to SDR.
    # Direct capture with bitdepth 10 + HDR produces oversaturated colors.
    display = "portal";
    matchMonitorName = "LG ULTRAGEAR";
    # DaVinci Resolve doesn't accept MKV.
    container = "mp4";
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
  #       open-on-output = "HDMI-A-1";
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
  # | ASUS | |  LG  | |HDMI-A-1|
  #  ------   ------  |(rot)|
  #                    ----
  display.defaultMonitor.enable = false;

  wayland.windowManager.hyprland.settings = {
    workspace = [
      "1, monitor:DP-3, default:true"
      "6, monitor:DP-3, default:true"
      "2, monitor:DP-1, default:true"
      "3, monitor:HDMI-A-1, default:true"
    ];
    windowrule = [
      "workspace 3 silent, match:class ^(Slack)$"
      "workspace 3 silent, match:title .*([Dd]iscord|[Ll]egcord).*"
      "workspace 2 silent, match:class ^(zen(-beta)?)$"
      "workspace 6 silent, match:class ^([Ss]team)$"
    ];
  };

  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs.discord-legcord}/share/applications/legcord.desktop"
      "${config.programs.zen-browser.package}/share/applications/zen-beta.desktop"
      "${pkgs._1password-gui}/share/applications/1password.desktop"
      "${config.programs.spicetify.spicedSpotify}/share/applications/spotify.desktop"
      "${pkgs.steam}/share/applications/steam.desktop"
    ];
  };

  display.monitors = [
    {
      output = "DP-1";
      name = "left";
      width = 3840;
      height = 2160;
      refreshRate = 144;
      x = 0;
      y = 0;
      bitdepth = 10;
      hdr = true;
    }
    {
      output = "DP-3";
      name = "main";
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
      output = "HDMI-A-1";
      name = "right";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      transform = "270";
      x = 7680;
      y = 240; # bottom-aligned with DP-3 (2160 - 1920 = 240)
    }
  ];
}
