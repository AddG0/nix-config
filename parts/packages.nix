# Clean packages module - only depends on nixpkgs
{ inputs, ... }:

{
  # Only import nixpkgs - no other heavy dependencies
  perSystem = { pkgs, lib, system, ... }: {
    # Custom packages from pkgs/common directory
    packages = lib.packagesFromDirectoryRecursive {
      inherit (pkgs) callPackage;
      directory = ../pkgs/common;
    };

    # Package checks/tests
    checks = {
      # Add package-specific checks here
      # e.g., packages-build = pkgs.runCommand "test-packages" {} ''
      #   ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: pkg: "${pkg}") packages)}
      #   touch $out
      # '';
    };
  };

  # Make packages available as flake outputs
  flake = {
    # Re-export packages for easy access
    # Usage: nix build .#package-name
    # Or from another flake: inputs.your-flake.packages.${system}.package-name
  };
}