# pkgs/flake-module.nix - Custom packages
{
  inputs,
  self,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: {
    packages = let
      # Base packages available on all systems
      basePackages = {
        # Add your custom packages here using callPackage
        # Example: mypackage = pkgs.callPackage ./mypackage { };
      };

      # Linux-specific packages
      linuxPackages = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
        # Add Linux-specific packages here
        # Example: linux-tool = pkgs.callPackage ./linux-tool { };
      };

      # Darwin-specific packages
      darwinPackages = lib.optionalAttrs (pkgs.stdenv.hostPlatform.isDarwin) {
        # Add macOS-specific packages here
        # Example: macos-tool = pkgs.callPackage ./macos-tool { };
      };

      # Custom packages from directory - only top-level packages to avoid nesting issues
      customPackages = let
        pkgsWithOverlays = import inputs.nixpkgs {
          inherit system;
          overlays = [inputs.self.overlays.default];
        };
        allPackages = lib.packagesFromDirectoryRecursive {
          inherit (pkgsWithOverlays) callPackage;
          directory = ./common;
        };
        # Only include packages that are derivations at the top level and compatible with current system
        topLevelPackages =
          lib.filterAttrs (
            name: value:
              lib.isDerivation value
              &&
              # Check if package is supported on current platform
              (!(value ? meta.platforms) || lib.any (p: p == system) value.meta.platforms)
              &&
              # Check if package is not in badPlatforms for current system
              (!(value ? meta.badPlatforms) || !lib.any (p: p == system) value.meta.badPlatforms)
          )
          allPackages;
      in
        topLevelPackages;
    in
      basePackages // linuxPackages // darwinPackages // customPackages;
  };

  flake = {
    # Using legacyPackages to allow nested structures like themes.catppuccin.ghostty
    legacyPackages = let
      systems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin"];
    in
      lib.genAttrs systems (system: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [inputs.self.overlays.default];
        };
      in
        lib.packagesFromDirectoryRecursive {
          inherit (pkgs) callPackage;
          directory = ./common;
        });
  };
}
