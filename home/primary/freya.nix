{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = lib.flatten [
    lib.custom.suites.development.home
    lib.custom.suites.ai.home
    lib.custom.suites.virtualization.home
    (with lib.custom.optional.home; [
      browsers
      comms
      ghostty
      helper-scripts
      librepods
      mic-mute-sound
    ])
    (with lib.custom.optional.home.desktops; [
      hyprland.nvidia
      hyprland.software-dimming
      # plasma6
    ])
    (with lib.custom.optional.home.development; [
      ai.ai-proxy
      aws
      bootdev
      gcloud
      # grpc
      ide.jetbrains-remote
      # ide.vscode-server
      jprofiler
      # jupyter-notebook
      postman
      terraform
      # tilt
      virtualization.lens
      virtualization.nixos-shell
    ])
    (with lib.custom.optional.home.gaming; [crosshair heroic minecraft nitrox r2modman rocket-league])
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
    (with lib.custom.optional.home.tools; [
      # freecad
      # gromit-mpx
      krita
      obsidian
      stylus-notes
      wayscriber
    ])
    (with lib.custom.optional.primary; [stylix work])
    (with lib.custom.optional.primary.development; [aws])
    (with lib.custom.optional.primary.secrets; [onepassword-ssh])
  ];

  dolphin.extraPlaces = [
    {
      title = "NAS Videos";
      href = "smb://10.61.60.49/videos";
      icon = "folder-videos";
    }
  ];

  # The bar defaults to always-on and space-reserving, which is what we want
  # on external (non-OLED) monitors. OLED panels override it to auto-hide,
  # avoiding static-bar burn-in; derived from the oled flags in display.monitors.
  programs.noctalia.settings.bar.main.monitor = builtins.listToAttrs (map (m: {
    name = m.output;
    value = {
      match = m.output;
      auto_hide = true;
      reserve_space = false;
    };
  }) (builtins.filter (m: m.oled or false) config.display.monitors));

  wayland.windowManager.hyprland.settings = {
    # Razer Blade 16 macro keys (remapped in hosts/nixos/freya). xkb's us
    # layout does not produce the F13/F14/F15 keysyms for those kernel
    # keycodes — it emits XF86Tools/XF86Launch5/XF86Launch6 instead.
    # Hyprland matches on keysym name, so the binds use those.
    #   M3 → kernel KEY_F13 → keysym XF86Tools     (hwdb, was 0x700d5)
    #   M4 → kernel KEY_F14 → keysym XF86Launch5   (hwdb, was 0x700d3)
    #   M5 → kernel KEY_F15 → keysym XF86Launch6   (keyd, was Meta+Alt+K)
    bind = [
      ", XF86Launch5, exec, ${config.programs.noctalia.package}/bin/noctalia msg power-cycle"
      ", XF86Launch6, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
    ];
  };

  # On top of the shared list in primary/common/optional/desktops/autostart.nix.
  xdg.autostart.entries = [
    "${config.programs.zen-browser.package}/share/applications/zen-beta.desktop"
  ];
}
