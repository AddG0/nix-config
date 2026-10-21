# Exposes every tests.nix and tests/default.nix under modules/ and home/, each `{pkgs, lib, self, ...}: <derivation>`, as check module-test-<module dir>.
{self, ...}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    checks = let
      testFiles = lib.concatMap (
        root:
          builtins.filter isTestEntry
          (lib.filesystem.listFilesRecursive root)
      ) [../modules ../home];

      isSuite = p: baseNameOf p == "default.nix" && baseNameOf (dirOf p) == "tests";
      isTestEntry = p: baseNameOf p == "tests.nix" || isSuite p;
      moduleDir = p:
        if isSuite p
        then dirOf (dirOf p)
        else dirOf p;
      checkName = p: "module-test-${lib.replaceStrings ["/"] ["-"] (lib.removePrefix "./" (lib.path.removePrefix ../. (moduleDir p)))}";

      named = map (p: lib.nameValuePair (checkName p) (import p {inherit pkgs lib self;})) testFiles;

      names = map (x: x.name) named;
    in
      # `/` → `-` can still merge two paths (`a-b/c`, `a/b-c`), and listToAttrs would keep only the last.
      lib.throwIf (lib.length names != lib.length (lib.unique names))
      "checks/module-tests.nix: two test entries map to the same check name: ${lib.concatStringsSep ", " names}"
      (lib.listToAttrs named);
  };
}
