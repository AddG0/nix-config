{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.plasma.workspace.splashScreen;

  # Map of splash screen theme names to their packages
  splashScreenPackages = {
    "Noir-Splash-6" = pkgs.themes.plasma.noir-splash-6;
  };

  # Get the package for the configured splash screen
  selectedSplashPackage = splashScreenPackages.${cfg.theme} or null;
in {
  config = mkIf (cfg.theme != null && selectedSplashPackage != null) {
    # Symlink splash screen to XDG location
    xdg.dataFile."plasma/look-and-feel/${cfg.theme}".source = "${selectedSplashPackage}/share/plasma/look-and-feel/${cfg.theme}";
  };
}
