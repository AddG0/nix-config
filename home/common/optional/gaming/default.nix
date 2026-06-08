{pkgs, ...}: {
  imports = [
    ./steam.nix
    ./sens-convert.nix
  ];

  home.packages = with pkgs; [
    mangohud
  ];

  # Forza Horizon's XWayland fullscreen-on-map path crashes Hyprland 0.54.3
  # inside CCompositor::setWindowFullscreenInternal (null deref on the
  # surface-recycling that happens during X11 Activate). Suppress the
  # fullscreen request — the game still renders fine windowed-borderless.
  wayland.windowManager.hyprland.settings.windowrule = [
    "suppress_event fullscreen, match:title ^(Forza Horizon \\d+)$"
    "suppress_event fullscreen, match:class ^(steam_app_2483190)$"
  ];

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
