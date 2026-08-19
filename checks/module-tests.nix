# checks/module-tests.nix - Auto-discover colocated module tests
#
# Any `tests.nix` placed next to a module is picked up here and exposed as a
# `nix flake check` check named `module-test-<dir>`. Each tests.nix is a
# function `{pkgs, lib, self, ...}: <derivation>`.
{self, ...}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    checks = let
      testFiles = lib.concatMap (
        root:
          builtins.filter (p: baseNameOf p == "tests.nix")
          (lib.filesystem.listFilesRecursive root)
      ) [../modules ../home];

      named =
        map (
          p:
            lib.nameValuePair
            "module-test-${baseNameOf (dirOf p)}"
            (import p {inherit pkgs lib self;})
        )
        testFiles;

      names = map (x: x.name) named;
    in
      # listToAttrs would silently keep only the last of a duplicate pair.
      lib.throwIf (lib.length names != lib.length (lib.unique names))
      "checks/module-tests.nix: two tests.nix files share a directory name: ${lib.concatStringsSep ", " names}"
      (lib.listToAttrs named);
  };
}
