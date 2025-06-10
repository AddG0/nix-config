# checks/packages.nix - Package build validation
{...}: {
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
            # Only include packages that are available on this platform
            && (builtins.tryEval v).success
            && (v.meta.available or true)
            && !(v.meta.broken or false)
        )
        self'.packages
      );
    in
      packageChecks;
  };
}
