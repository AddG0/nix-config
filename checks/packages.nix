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

      checkedPackages =
        lib.filterAttrs (
          n: v:
            !(builtins.any (blacklist: lib.hasPrefix blacklist n) blacklistPackages)
            # No tryEval: an eval error must fail the check, not drop it; platform filtering happens upstream in pkgs/flake-module.nix.
            && (v.meta.available or true)
            && !(v.meta.broken or false)
        )
        self'.packages;

      packageChecks = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") checkedPackages;

      # A package's passthru.tests cover what building it cannot, such as the result running.
      testChecks = lib.concatMapAttrs (n: pkg: lib.mapAttrs' (t: lib.nameValuePair "package-${n}-test-${t}") (pkg.passthru.tests or {})) checkedPackages;
    in
      packageChecks // testChecks;
  };
}
