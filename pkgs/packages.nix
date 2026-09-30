# Our package scope, built from pkgs/by-name (nixpkgs by-name layout: <name>/package.nix or <name>.nix; other dirs nest).
# Exposed as pkgs.addg by overlays/packages.nix.
pkgs:
pkgs.lib.packagesFromDirectoryRecursive {
  inherit (pkgs) callPackage newScope;
  directory = ./by-name;
}
