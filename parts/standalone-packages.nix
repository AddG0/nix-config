# parts/standalone-packages.nix
# This part only uses inputs that packages actually need
{inputs, ...}: {
  # Override the pkgs used for packages to only include necessary overlays
  perSystem = {system, ...}: {
    packages = let
      # Create a minimal pkgs just for packages
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          # Only include overlays that your packages actually need
          # Don't include heavy ones like stylix, etc.
        ];
      };
      lib = pkgs.lib;
    in
      lib.packagesFromDirectoryRecursive {
        inherit (pkgs) callPackage;
        directory = ../pkgs/common;
      };
  };

  flake = {
    # Export a clean overlay
    overlays.packages = final: prev: let
      lib = final.lib;
    in
      lib.packagesFromDirectoryRecursive {
        callPackage = final.callPackage;
        directory = ./pkgs/common;
      };
  };
}
