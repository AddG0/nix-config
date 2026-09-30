{
  lib,
  pkgs,
  ...
}: {
  assertions = [(lib.hm.assertions.assertPlatform "home.desktops.hyprland.personal" pkgs lib.platforms.linux)];

  imports = [
    ../_common
    ./visuals.nix
    ./noctalia
    # ./anyrun.nix
    ./walker.nix
    ./pip.nix
    ./hyprlock.nix
    ./wallpaper-defaults.nix
  ];
}
