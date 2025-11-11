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
  selectedIconPackage = iconThemePackages.${cfg.iconTheme} or null;
in {
  config = mkIf (config.programs.plasma.enable && cfg.iconTheme != null && selectedIconPackage != null) {
    # Symlink to XDG location
    xdg.dataFile."icons/${cfg.iconTheme}".source = "${selectedIconPackage}/share/icons/${cfg.iconTheme}";
  };
}
