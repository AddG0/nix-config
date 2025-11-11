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
  selectedSplashPackage =
    if cfg.theme != null
    then splashScreenPackages.${cfg.theme} or null
    else null;
in {
  config = mkIf (cfg.theme != null && selectedSplashPackage != null) (
    let
      attrName = "plasma/look-and-feel/${cfg.theme}";
      sourcePath = "${selectedSplashPackage}/share/plasma/look-and-feel/${cfg.theme}";
    in {
      # Symlink splash screen to XDG location
      xdg.dataFile.${attrName}.source = sourcePath;
    }
  );
}
