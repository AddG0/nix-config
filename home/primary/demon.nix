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
      # plasma6
    ])
    (with lib.custom.optional.home.development; [
      ai.ai-proxy
      aws
      bootdev
      gcloud
      grpc
      ide.jetbrains-remote
      ide.vscode-server
      jprofiler
      jupyter-notebook
      postman
      terraform
      tilt
      virtualization.kubernetes
      virtualization.lens
      virtualization.nixos-shell
    ])
    (with lib.custom.optional.home.gaming; [
      bigscreen-beyond
      crosshair
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
    (with lib.custom.optional.primary.development; [node])
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

  dolphin.extraPlaces = [
    {
      title = "NAS Videos";
      href = "smb://10.61.60.49/videos";
      icon = "folder-videos";
    }
  ];

  services.gpu-screen-recorder = {
    # KMS capture, not portal: any Hyprland screencopy blocks direct scanout.
    # Needs an HDR codec, or the 10-bit HDR framebuffer comes out oversaturated.
    matchMonitorName = "LG ULTRAGEAR";
    codec = "hevc_hdr";
    # DaVinci Resolve doesn't accept MKV.
    container = "mp4";
  };

  wayland.windowManager.hyprland.settings = {
    workspace = [
      "1, monitor:DP-3, default:true"
      "6, monitor:DP-3, default:true"
      "2, monitor:DP-2, default:true"
      "3, monitor:HDMI-A-1, default:true"
    ];
  };

  # niri's workspaces are per monitor, so Hyprland's pinned numbers become named ones a
  # monitor owns; Mod+N reaches them from anywhere. The other numbers stay per-monitor.
  programs.niri.settings = let
    pinned = {
      "1" = "DP-3";
      "6" = "DP-3";
      "2" = "DP-2";
      "3" = "HDMI-A-1";
    };
  in {
    workspaces = lib.mapAttrs' (name: output:
      lib.nameValuePair "0${name}" {
        inherit name;
        open-on-output = output;
      })
    pinned;
    binds = lib.mkMerge (lib.mapAttrsToList (name: _: {
        "Mod+${name}".action = lib.mkForce {focus-workspace = name;};
        "Mod+Shift+${name}".action = lib.mkForce {move-column-to-workspace = name;};
      })
      pinned);
  };

  # On top of the shared list in primary/common/optional/desktops/autostart.nix.
  xdg.autostart.entries = [
    "${config.programs.zen-browser.package}/share/applications/zen-beta.desktop"
    "${pkgs.steam}/share/applications/steam.desktop"
    "${pkgs.obsidian}/share/applications/md.obsidian.Obsidian.desktop"
  ];
}
