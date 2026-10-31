{
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [browsers comms ghostty])
    (with lib.custom.optional.home.desktops; [hyprland.nvidia])
    (with lib.custom.optional.home.gaming; [minecraft])
    (with lib.custom.optional.home.media; [core spicetify vlc])
    (with lib.custom.optional.primary; [stylix])
    (with lib.custom.optional.primary.secrets; [onepassword-ssh])
  ];

  desktops.defaultSession = "hyprland";

  # On top of the shared list in primary/common/optional/desktops/autostart.nix.
  xdg.autostart.entries = ["${pkgs.steam}/share/applications/steam.desktop"];
}
