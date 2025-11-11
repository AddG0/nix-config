{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.plasma.workspace;

  # Map of icon theme names to their packages
  iconThemePackages = {
    "Papirus-Dark" = pkgs.papirus-icon-theme;
    "Papirus" = pkgs.papirus-icon-theme;
    "Papirus-Light" = pkgs.papirus-icon-theme;
  };

  # Get the package for the configured icon theme
  selectedIconPackage =
    if cfg.iconTheme != null
    then iconThemePackages.${cfg.iconTheme} or null
    else null;
in {
  config = mkIf (cfg.iconTheme != null && selectedIconPackage != null) {
    # Symlink to XDG location
    xdg.dataFile."icons/${cfg.iconTheme}".source = "${selectedIconPackage}/share/icons/${cfg.iconTheme}";
  };
}
