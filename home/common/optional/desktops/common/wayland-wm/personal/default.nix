{
  lib,
  pkgs,
  ...
}: {
  assertions = [(lib.hm.assertions.assertPlatform "home.desktops.common.wayland-wm.personal" pkgs lib.platforms.linux)];

  imports = [
    ./visuals.nix
    ./noctalia
    ./walker.nix
    ./hyprlock.nix
    ./wallpaper-defaults.nix
    ./_hyprland.nix
    ./_niri.nix
  ];
}
