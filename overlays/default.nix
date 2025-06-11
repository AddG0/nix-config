#
# This file defines overlays/custom modifications to upstream packages
#
{inputs, ...}: let
  # Adds my custom packages
  additions = final: prev:
    prev.lib.packagesFromDirectoryRecursive {
      callPackage = prev.lib.callPackageWith final;
      directory = ../pkgs/common;
    };

  linuxModifications = final: prev:
    if prev.stdenv.isLinux
    then {
      # Linux-specific packages here
    }
    else {};

  darwinModifications = final: prev:
    if prev.stdenv.isDarwin
    then {
      # Darwin-specific packages here
    }
    else {};

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

    ghostty = inputs.ghostty.packages.${prev.system}.default;
    zen-browser = inputs.zen-browser.packages.${prev.system}.default;
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

  nur = final: _prev: let
    importedNur = import inputs.nur {
      pkgs = final;
      nurpkgs = final;
    };
  in {
    nur =
      importedNur
      // {
        repos =
          importedNur.repos
          // {
            xddxdd =
              importedNur.repos.xddxdd
              // {
                pterodactyl-wings = importedNur.repos.xddxdd.pterodactyl-wings.overrideAttrs (old: {
                  doCheck = false;
                  # Fix hash mismatch for go modules
                  vendorHash = "sha256-tfv3jUoIQxFVshooe1f9K2v6vxXx8C02QdP/dcwz8vE=";
                });
              };
          };
      };
  };
in {
  default = final: prev:
    (additions final prev)
    // (modifications final prev)
    // (linuxModifications final prev)
    // (darwinModifications final prev)
    // (stable-packages final prev)
    // (unstable-packages final prev)
    // (nur final prev);
}
