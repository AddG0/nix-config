{
  pkgs,
  customPkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    mangohud
  ];

  # Proton bakes dirname(sys.argv[0]) into each prefix, never realpath'd, so
  # these names must stay stable; a store path dies with its last generation.
  xdg.dataFile."Steam/compatibilitytools.d/GE-Proton".source =
    pkgs.proton-ge-bin.steamcompattool;
  xdg.dataFile."Steam/compatibilitytools.d/proton-cachyos-native".source = "${customPkgs.proton-cachyos}/share/steam/compatibilitytools.d/proton-cachyos-native";

  # Forza Horizon's XWayland fullscreen-on-map path crashes Hyprland 0.54.3
  # inside CCompositor::setWindowFullscreenInternal (null deref on the
  # surface-recycling that happens during X11 Activate). Suppress the
  # fullscreen request — the game still renders fine windowed-borderless.
  # mkBefore so `tag +game` sorts ahead of the tag:game consumers in other
  # modules (e.g. the opacity rule in visuals) — Hyprland applies rules in order.
  wayland.windowManager.hyprland.settings.windowrule = lib.mkBefore [
    "suppress_event fullscreen, match:title ^(Forza Horizon \\d+)$"
    "suppress_event fullscreen, match:class ^(steam_app_2483190)$"
    # Scrap Mechanic maps its X11 window as a dialog, so Hyprland auto-floats it tiny.
    "float off, match:class ^(steam_app_387990)$"
    # gamescope's render loop runs off Wayland frame callbacks, which Hyprland
    # stops sending to windows on an inactive workspace — so the game freezes on
    # return until a resize kicks it.
    "render_unfocused on, match:class ^(gamescope)$"
    # Steam games (Proton or native) map as XWayland class steam_app_<id>.
    "tag +game, match:class ^(steam_app_\\d+)$"
    # Gamescoped ones don't: they map on gamescope's Xwayland, not Hyprland's.
    "tag +game, match:class ^(gamescope)$"
    # render.direct_scanout = 2 only scans out windows of content type game.
    # Not gamescope: Hyprland scanning out its buffer directly shows garbage.
    "content game, match:tag game, match:class negative:^(gamescope)$"
  ];

  wayland.windowManager.hyprland.settings.render = {
    direct_scanout = 2;
    # Default 3 ignores CM for scanout, so SDR games on an HDR output go oversaturated.
    non_shader_cm = 2;
  };

  # Disable the desktop entry for Protontricks since steam gives me that option anyway
  #
  # Written to $XDG_DATA_HOME directly (not via xdg.desktopEntries) because
  # walker's elephant backend dedupes .desktop files by basename and scans
  # $XDG_DATA_HOME before $XDG_DATA_DIRS — so a file here masks the system
  # entry; one in the HM profile share dir doesn't reliably win.
  xdg.dataFile."applications/protontricks.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Protontricks
    NoDisplay=true
  '';
}
