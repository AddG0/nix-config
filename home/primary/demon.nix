{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = lib.flatten [
    # lib.custom.suites.virtualization.home
    lib.custom.suites.development.home
    lib.custom.suites.ai.home
    (with lib.custom.optional.home; [browsers comms ghostty helper-scripts mic-mute-sound])
    (with lib.custom.optional.home.desktops; [
      hyprland.nvidia
      hyprland.software-dimming
      # hyprland.sunshine
      hyprland.wlcrosshair
      # plasma6
    ])
    (with lib.custom.optional.home.development; [
      ai.ai-proxy
      ai.t3code-server
      aws
      bootdev
      gcloud
      grpc
      ide.jetbrains-remote
      ide.vscode-server
      jprofiler
      jupyter-notebook
      nomad
      postman
      terraform
      tilt
      virtualization.kubernetes
      virtualization.lens
      virtualization.nixos-shell
    ])
    (with lib.custom.optional.home.gaming; [
      bigscreen-beyond
      heroic
      minecraft
      nitrox
      queued-build-cache-pause
      r2modman
      rocket-league
    ])
    (with lib.custom.optional.home.media; [
      core
      davinci-resolve
      spicetify
      # tidal
      vlc
    ])
    (with lib.custom.optional.home.remote-desktop; [
      # mouseshare.lan-mouse
      # rustdesk
    ])
    (with lib.custom.optional.home.secrets; [ai buf sops elevenlabs kubeconfig])
    (with lib.custom.optional.home.services; [gpu-screen-recorder hass-agent safeeyes])
    (with lib.custom.optional.home.tools; [
      bottles
      # freecad
      fusion360
      krita
      obsidian
      stylus-notes
      wayscriber
    ])
    (with lib.custom.optional.primary; [stylix work])
    (with lib.custom.optional.primary.development; [aws node])
    (with lib.custom.optional.primary.secrets; [onepassword-ssh])
    (with lib.custom.optional.primary.services; [rclone])
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
      "${pkgs._1password-gui}/share/applications/com.onepassword.OnePassword.desktop"
      "${config.programs.spicetify.spicedSpotify}/share/applications/spotify.desktop"
      "${pkgs.steam}/share/applications/steam.desktop"
      "${pkgs.obsidian}/share/applications/md.obsidian.Obsidian.desktop"
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
