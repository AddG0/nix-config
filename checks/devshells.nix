# checks/devshells.nix - Development shell validation
_: {
  perSystem = {
    self',
    lib,
    ...
  }: {
    checks = let
      # DevShell checks - validate that devShells can be built
      devShellChecks = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
    in
      devShellChecks;
  };
}
