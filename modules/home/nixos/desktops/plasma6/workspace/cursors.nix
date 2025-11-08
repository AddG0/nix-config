{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.plasma.workspace.cursor;

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
  selectedCursorPackage = cursorThemePackages.${cfg.theme} or null;
in {
  config = mkIf (cfg.theme != null && selectedCursorPackage != null) {
    # Symlink to XDG location
    xdg.dataFile."icons/${cfg.theme}".source = "${selectedCursorPackage}/share/icons/${cfg.theme}";
  };
}
