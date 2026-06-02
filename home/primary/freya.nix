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
        "mic-mute-sound.nix"

        # Development
        "development"
        # "development/ide/vscode/server.nix"
        # "development/ide/jetbrains-remote.nix"
        # "development/jupyter-notebook.nix"
        # "development/virtualization/nixos-shell.nix"
        "development/ai"
        "development/postman.nix"
        "development/gcloud.nix"
        "development/aws.nix"
        "development/virtualization"
        "development/virtualization/lens.nix"
        "development/virtualization/kubernetes"
        "development/virtualization/nixos-shell.nix"
        # "development/ai/litellm-proxy.nix"

        "development/languages"
        "development/tilt.nix"
        "development/grpc.nix"
        "secrets/buf.nix"
        "development/terraform.nix"
        "development/bootdev.nix"
        "development/nomad.nix"

        # Gaming
        "gaming/steam.nix"
        "gaming/minecraft"
        "gaming/heroic.nix"
        "gaming/r2modman.nix"
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
        "nixos/desktops/hyprland/software-dimming.nix"
        "nixos/desktops/hyprland/nvidia.nix"
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

  programs.noctalia-shell.settings.bar = {
    displayMode = "auto_hide";
    autoHideDelay = 500;
    autoShowDelay = 150;
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
  # --------
  # | eDP-1 |
  # | 2560x1600@240Hz |
  # | Samsung built-in |
  # --------
  display.defaultMonitor.enable = false;

  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "workspace 3 silent, match:class ^(Slack)$"
      "workspace 3 silent, match:title .*([Dd]iscord|[Ll]egcord).*"
      "workspace 2 silent, match:class ^(zen(-beta)?)$"
      "workspace 6 silent, match:class ^([Ss]team)$"
    ];
    # Razer Blade 16 macro keys (remapped in hosts/nixos/freya). xkb's us
    # layout does not produce the F13/F14/F15 keysyms for those kernel
    # keycodes — it emits XF86Tools/XF86Launch5/XF86Launch6 instead.
    # Hyprland matches on keysym name, so the binds use those.
    #   M3 → kernel KEY_F13 → keysym XF86Tools     (hwdb, was 0x700d5)
    #   M4 → kernel KEY_F14 → keysym XF86Launch5   (hwdb, was 0x700d3)
    #   M5 → kernel KEY_F15 → keysym XF86Launch6   (keyd, was Meta+Alt+K)
    bind = [
      ", XF86Launch5, exec, ${config.programs.noctalia-shell.package}/bin/noctalia-shell ipc call powerProfile cycle"
      ", XF86Launch6, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
    ];
  };

  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs.discord-legcord}/share/applications/legcord.desktop"
      "${config.programs.zen-browser.package}/share/applications/zen-beta.desktop"
      "${pkgs._1password-gui}/share/applications/1password.desktop"
      "${config.programs.spicetify.spicedSpotify}/share/applications/spotify.desktop"
    ];
  };

  display.monitors = [
    {
      output = "eDP-1";
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
