# checks/packages.nix - Package build validation
_: {
  perSystem = {
    self',
    lib,
    ...
  }: {
    checks = let
      # Package checks - validate that packages build
      blacklistPackages = [
        # Add packages that shouldn't be checked here
        "install-iso"
        "vm-" # Skip VM images in checks as they're large
      ];

      packageChecks = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") (
        lib.filterAttrs (
          n: v:
            !(builtins.any (blacklist: lib.hasPrefix blacklist n) blacklistPackages)
            # No tryEval: an eval error must fail the check, not drop it; platform filtering happens upstream in pkgs/flake-module.nix.
            && (v.meta.available or true)
            && !(v.meta.broken or false)
        )
        self'.packages
      );
    in
      packageChecks;
  };
}
