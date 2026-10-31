{lib, ...}: {
  imports = lib.flatten [
    (with lib.custom.optional.home.desktops; [hyprland.nvidia])
    (with lib.custom.optional.home.gaming; [minecraft])
    (with lib.custom.optional.primary; [stylix])
  ];

  desktops.defaultSession = "hyprland";
}
