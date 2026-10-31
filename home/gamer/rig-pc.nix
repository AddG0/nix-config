{
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [browsers])
    (with lib.custom.optional.home.gaming; [minecraft])
  ];

  # The host also installs Hyprland for addg; gamer's console desktop stays Plasma.
  desktops.defaultSession = "plasma";

  xdg.autostart = {
    enable = true;
    entries = ["${pkgs.steam}/share/applications/steam.desktop"];
  };
}
