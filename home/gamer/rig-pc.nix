{
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [browsers])
    (with lib.custom.optional.home.gaming; [minecraft])
  ];

  xdg.autostart = {
    enable = true;
    entries = ["${pkgs.steam}/share/applications/steam.desktop"];
  };
}
