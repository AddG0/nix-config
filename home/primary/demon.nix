{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = lib.flatten [
    (map (f: ./common/optional/${f}) [
      "development/aws.nix"
      "nixos/services/rclone.nix"
      "stylix.nix"
      "work.nix"
    ])

    (map lib.custom.relativeToHome (map (f: "common/optional/${f}") [
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
      "development/jprofiler.nix"
      "development/gcloud.nix"
      "development/aws.nix"
      # "development/virtualization"
      "development/virtualization/lens.nix"
      "development/virtualization/kubernetes"
      "development/ai/litellm-proxy.nix"

      "development/tilt.nix"
      "development/grpc.nix"
      "development/terraform.nix"
      "development/bootdev.nix"
      "development/nomad.nix"
      "secrets/buf.nix"
      "development/ai/t3code/server.nix"

      # Gaming
      "gaming"
      "gaming/minecraft"
      "gaming/heroic.nix"
      "gaming/r2modman.nix"
      "gaming/nitrox.nix"
      "gaming/bigscreen-beyond.nix"
      "gaming/bakkesmod.nix"
      "gaming/queued-build-cache-pause.nix"

      # Ghostty (Terminal)
      "ghostty"

      # Media
      "media"
      "media/spicetify.nix"
      "media/davinci-resolve.nix"
      # "media/tidal.nix"

      # Tools
      "tools/wayscriber.nix"
      # "tools/freecad.nix"
      "tools/obsidian.nix"
      "tools/krita.nix"
      "tools/stylus-notes.nix"
      "tools/bottles.nix"
      "tools/fusion360.nix"

      # NixOS Specific
      # "nixos/desktops/plasma6"
      "nixos/desktops/hyprland"
      "nixos/desktops/hyprland/nvidia.nix"
      # "nixos/desktops/hyprland/sunshine.nix"
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
    ]))
  ];

  # Record from the never-muted direct_input node (demon audio/virtual-devices.nix),
  # so Claude Code keeps hearing me when I hit mic-mute.
  programs.claude-code-profiles.captureNode = "direct_input";

  # Bobby's fake chunks scale with render distance squared; the shared 8G OOMs.
  programs.prismlauncher.modpacks =
    lib.genAttrs [
      "main-1.21.11"
      "main-1.21.11-smp"
      "main-1.21.11-pvp-practice"
    ] (_: {
      maxMemory = 24576;
      # ZGC keeps pauses sub-ms at this heap size; G1's young collections ran ~42ms.
      javaArgs = "-XX:+UseZGC";
    });

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
  #       matches = [{app-id = "^discord$";}];
  #       open-on-workspace = "chat";
  #     }
  #   ];
  # };

  #
  # ========== Host-specific Monitor Spec ==========
  #
  #  ------   ------
  # | DP-2 | | DP-3 | ----
  # | ASUS | |  LG  | |HDMI-A-1|
  #  ------   ------  |(rot)|
  #                    ----
  display.defaultMonitor.enable = false;

  wayland.windowManager.hyprland.settings = {
    workspace = [
      "1, monitor:DP-3, default:true"
      "6, monitor:DP-3, default:true"
      "2, monitor:DP-2, default:true"
      "3, monitor:HDMI-A-1, default:true"
    ];
    windowrule = [
      "workspace 3 silent, match:class ^(slack)$"
      "workspace 3 silent, match:title .*([Dd]iscord|[Ll]egcord).*"
      "workspace 2 silent, match:class ^(zen(-beta)?)$"
      "workspace 6 silent, match:class ^([Ss]team)$"
      # Updater dialog maps with an empty class, so the rule above misses it.
      "workspace 6 silent, match:class ^$, match:title ^Steam$"
    ];
  };

  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs.discord}/share/applications/discord.desktop"
      "${config.programs.zen-browser.package}/share/applications/zen-beta.desktop"
      "${pkgs._1password-gui}/share/applications/1password.desktop"
      "${config.programs.spicetify.spicedSpotify}/share/applications/spotify.desktop"
      "${pkgs.steam}/share/applications/steam.desktop"
      "${pkgs.obsidian}/share/applications/obsidian.desktop"
    ];
  };

  display.monitors = [
    {
      output = "DP-2";
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
      width = 3840;
      height = 2160;
      refreshRate = 120;
      scale = 1.2; # matches DP-3's logical px/mm so the portrait spans its true physical height
      transform = "270";
      x = 7680;
      y = -732; # 597mm panel overhangs the 392mm DP-3 by 205mm; ~56mm of that below its bottom edge
    }
  ];
}
