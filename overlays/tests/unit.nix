# overlaid-packages.nix finds the packages fixture overlays set themselves in a fake package set, and returns them as build targets.
{lib, ...}: let
  drv = name: {
    type = "derivation";
    inherit name;
  };
  pkgs = {
    package = drv "package";
    plugins = {
      patched = drv "patched";
      untouched = drv "untouched";
    };
    addons = {
      checked = drv "checked";
      other = drv "other";
    };
    removedPackage = throw "removed upstream";
  };

  overlaid = files: filters:
    import ../overlaid-packages.nix {inherit lib;} {
      inputs = {};
      inherit pkgs files filters;
    };
in {
  "test a package two overlays patch is one target naming both" = {
    expr = (overlaid [./_patch-package.nix ./_patch-package-again.nix] []).overlaysByTarget;
    expected.package = ["tests/_patch-package.nix" "tests/_patch-package-again.nix"];
  };

  "test a package patched inside a set is a target at its full path, and its siblings are not" = {
    expr = lib.attrNames (overlaid [./_patch-plugin-in-set.nix] []).overlaysByTarget;
    expected = ["plugins.patched"];
  };

  "test a nested target is the package from pkgs, wrapped in attrsets nix-eval-jobs descends into" = {
    expr = (overlaid [./_patch-plugin-in-set.nix] []).targets;
    expected.plugins = {
      recurseForDerivations = true;
      patched = drv "patched";
    };
  };

  "test packages an overlay re-exports from a flake input's overlay are not targets" = {
    expr = (overlaid [./_reexport-input-overlay.nix] []).overlaysByTarget;
    expected = {};
  };

  "test a replaced set with no package of its own is reported, not built" = {
    expr = {inherit (overlaid [./_replace-addon-set.nix] []) overlaysByTarget nonPackageAttrPaths;};
    expected = {
      overlaysByTarget = {};
      nonPackageAttrPaths = ["tests/_replace-addon-set.nix: addons"];
    };
  };

  "test a CHECK-ATTR line names the package to build when the overlay replaces a whole set" = {
    expr = {inherit (overlaid [./_replace-addon-set-with-check-attr.nix] []) overlaysByTarget nonPackageAttrPaths;};
    expected = {
      overlaysByTarget."addons.checked" = ["tests/_replace-addon-set-with-check-attr.nix"];
      nonPackageAttrPaths = [];
    };
  };

  "test filters keep only targets patched by an overlay whose path contains one of them" = {
    expr = lib.attrNames (overlaid [./_patch-package.nix ./_patch-plugin-in-set.nix] ["plugin-in-set"]).overlaysByTarget;
    expected = ["plugins.patched"];
  };

  "test a filtered target still names every overlay that patches it" = {
    expr = (overlaid [./_patch-package.nix ./_patch-package-again.nix] ["again"]).overlaysByTarget;
    expected.package = ["tests/_patch-package.nix" "tests/_patch-package-again.nix"];
  };

  "test a package removed upstream stays a target instead of stopping discovery" = {
    expr = lib.attrNames (overlaid [./_patch-removed-package.nix ./_patch-package.nix] []).overlaysByTarget;
    expected = ["package" "removedPackage"];
  };

  "test overlay files that set nothing themselves are listed" = {
    expr = (overlaid [./_reexport-input-overlay.nix ./_patch-package.nix] []).overlaysSettingNothing;
    expected = ["tests/_reexport-input-overlay.nix"];
  };
}
