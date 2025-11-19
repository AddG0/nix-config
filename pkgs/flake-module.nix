# pkgs/flake-module.nix - Custom packages
{
  inputs,
  lib,
  ...
}: let
  # Import the shared package definitions
  mkCustomPackages = import ./packages.nix;
in {
  perSystem = {system, ...}: let
    # Override pkgs to allow insecure packages
    pkgs' = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
      };
    };
    allPackages = mkCustomPackages pkgs';

    # Flatten for packages output (only top-level derivations)
    flattenedPackages = let
      onlyForPlatform = pkg:
        if (pkg ? meta.platforms)
        then lib.elem system pkg.meta.platforms
        else true;

      collectDerivations = prefix: set:
        lib.concatMapAttrs (name: value:
          if lib.isDerivation value && onlyForPlatform value
          then {"${prefix}${name}" = value;}
          else if lib.isAttrs value && !lib.isDerivation value
          then collectDerivations "${prefix}${name}-" value
          else {})
        set;
    in
      collectDerivations "" allPackages;
  in {
    packages = flattenedPackages;
  };

  flake = {
    # Using legacyPackages to preserve nested structure
    legacyPackages = let
      systems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux"];
    in
      lib.genAttrs systems (system: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      in
        mkCustomPackages pkgs);
  };
}
