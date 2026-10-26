{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  # null when nothing sets a cursor, leaving Plasma's default.
  theme = config.programs.plasma.workspace.cursor.theme or null;

  # Map of cursor theme names to their packages
  cursorThemePackages = {
    "Vimix-cursors" = pkgs.vimix-cursors;
    "Vimix-white-cursors" = pkgs.vimix-cursors;
    "Bibata-Modern-Classic" = pkgs.bibata-cursors;
    "Bibata-Modern-Ice" = pkgs.bibata-cursors;
    "Bibata-Original-Classic" = pkgs.bibata-cursors;
    "Bibata-Original-Ice" = pkgs.bibata-cursors;
  };

  # Get the package for the configured cursor theme
  selectedCursorPackage = cursorThemePackages.${theme} or null;
in {
  config = mkIf (config.programs.plasma.enable && theme != null && selectedCursorPackage != null) {
    # Symlink to XDG location
    xdg.dataFile."icons/${theme}".source = "${selectedCursorPackage}/share/icons/${theme}";
  };
}
