# Autodesk Fusion 360 via Wine. See pkgs/fusion360 for the launcher/recipe.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.fusion360;
in {
  options.programs.fusion360 = {
    enable = lib.mkEnableOption "Autodesk Fusion 360 via Wine";
    package = lib.mkPackageOption pkgs "fusion360" {};
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    # After browser sign-in, Autodesk calls back via adskidmgr://; route it to the
    # Wine app or Fusion hangs at "Opening product".
    xdg.desktopEntries.fusion360-adskidmgr = {
      name = "Autodesk Fusion Login Callback";
      exec = "${lib.getExe cfg.package} --adskidmgr %u";
      noDisplay = true;
      mimeType = ["x-scheme-handler/adskidmgr"];
    };

    xdg.mimeApps.defaultApplications."x-scheme-handler/adskidmgr" = "fusion360-adskidmgr.desktop";
  };
}
