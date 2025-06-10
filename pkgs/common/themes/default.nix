{
  lib,
  callPackage,
  ...
}: let
  # Import all theme packages from subdirectories
  catppuccin = lib.packagesFromDirectoryRecursive {
    inherit callPackage;
    directory = ./catppuccin;
  };
in {
  # Export catppuccin themes
  inherit catppuccin;
}
