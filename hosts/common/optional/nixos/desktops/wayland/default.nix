{
  pkgs,
  lib,
  ...
}: {
  imports = lib.custom.scanPaths ./.;

  programs.hyprland = {
    enable = true;
  };

  # Allow file managers to discover plugged in devices
  services.udisks2.enable = true;
}
