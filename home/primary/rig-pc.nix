{lib, ...}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [browsers comms ghostty])
    (with lib.custom.optional.home.desktops; [hyprland.nvidia])
    (with lib.custom.optional.home.gaming; [minecraft])
    (with lib.custom.optional.home.media; [core spicetify vlc])
    (with lib.custom.optional.primary; [stylix])
    (with lib.custom.optional.primary.secrets; [onepassword-ssh])
  ];

  desktops.defaultSession = "hyprland";
}
