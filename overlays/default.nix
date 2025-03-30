#
# This file defines overlays/custom modifications to upstream packages
#
{
  inputs,
  ghostty,
  ...
}: let
  # Adds my custom packages
  additions = final: prev:
    prev.lib.packagesFromDirectoryRecursive {
      callPackage = prev.lib.callPackageWith final;
      directory = ../pkgs/common;
    };

  linuxModifications = final: prev:
    prev.lib.mkIf final.stdenv.isLinux {
      pterodactyl-wings = prev.nur.repos.xddxdd.pterodactyl-wings.overrideAttrs (old: {
        doCheck = false; # Disable tests to avoid reflect panic
      });
    };

  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: let ... in {
    # ...
    # });
    #    flameshot = prev.flameshot.overrideAttrs {
    #      cmakeFlags = [
    #        (prev.lib.cmakeBool "USE_WAYLAND_GRIM" true)
    #        (prev.lib.cmakeBool "USE_WAYLAND_CLIPBOARD" true)
    #      ];
    #    };
    ghostty = ghostty.packages.${prev.system}.default;
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      inherit (final) system;
      config.allowUnfree = true;
      #      overlays = [
      #     ];
    };
  };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
      #      overlays = [
      #     ];
    };
  };

  nur = final: _prev: {
    nur = import inputs.nur {
      pkgs = final;
      nurpkgs = final;
    };
  };
in {
  default = final: prev:
    (additions final prev)
    // (modifications final prev)
    // (linuxModifications final prev)
    // (stable-packages final prev)
    // (unstable-packages final prev)
    // (nur final prev);
}
