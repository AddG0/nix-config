# checks/module-tests.nix - Auto-discover colocated module tests
#
# Any `tests.nix` placed next to a module is picked up here and exposed as a
# `nix flake check` check named `module-test-<dir>`. Each tests.nix is a
# function `{pkgs, lib, ...}: <derivation>`.
_: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    checks = let
      testFiles =
        builtins.filter (p: baseNameOf p == "tests.nix")
        (lib.filesystem.listFilesRecursive ../modules);
    in
      lib.listToAttrs (
        map (
          p:
            lib.nameValuePair
            "module-test-${baseNameOf (dirOf p)}"
            (import p {inherit pkgs lib;})
        )
        testFiles
      );
  };
}
