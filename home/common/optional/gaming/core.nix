{
  pkgs,
  customPkgs,
  ...
}: {
  imports = [
    ./_hyprland.nix
    ./_window-classes.nix
  ];

  # Steam games (Proton or native) map as steam_app_<id>; gamescoped ones as gamescope,
  # since they run on gamescope's own Xwayland.
  gaming.windowClasses = ["^(steam_app_[0-9]+)$" "^(gamescope)$"];

  home.packages = with pkgs; [
    mangohud
  ];

  # Proton bakes dirname(sys.argv[0]) into each prefix, never realpath'd, so
  # these names must stay stable; a store path dies with its last generation.
  xdg.dataFile."Steam/compatibilitytools.d/GE-Proton".source =
    pkgs.proton-ge-bin.steamcompattool;
  xdg.dataFile."Steam/compatibilitytools.d/proton-cachyos-native".source = "${customPkgs.proton-cachyos}/share/steam/compatibilitytools.d/proton-cachyos-native";

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
