# Installs the shared wallhaven set into ~/Pictures/Wallpapers/default/ via
# `wallpapers.images` (declared in wallpaper.nix). Declaring the `default`
# folder auto-disables the stylix-image seed — see `wallpapers.defaultSeed.enable`.
{pkgs, ...}: {
  wallpapers.images.default = import ../../_wallhaven.nix {inherit pkgs;};
}
