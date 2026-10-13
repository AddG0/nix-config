# Exposes each lib/**/tests.nix — `{pkgs, lib, self, ...}: <derivation>` — as check lib-test-<dir>.
{self, ...}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    checks = let
      named =
        map (
          p:
            lib.nameValuePair
            "lib-test-${baseNameOf (dirOf p)}"
            (import p {inherit pkgs lib self;})
        )
        (builtins.filter (p: baseNameOf p == "tests.nix") (lib.filesystem.listFilesRecursive ../lib));

      names = map (x: x.name) named;
    in
      # listToAttrs would silently keep only the last of a duplicate pair.
      lib.throwIf (lib.length names != lib.length (lib.unique names))
      "checks/lib-tests.nix: two tests.nix files share a directory name: ${lib.concatStringsSep ", " names}"
      (lib.listToAttrs named);
  };
}
