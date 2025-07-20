{
  lib,
  pkgs,
  inputs,
  system,
  ...
}: {
  imports = lib.flatten [
    inputs.plasma-manager.homeManagerModules.plasma-manager
    (lib.custom.scanPaths ./.)
  ];

  home.packages = with pkgs; [
  ];
}
