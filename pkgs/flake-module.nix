# Our pkgs/ scope as flake outputs; configs read it as pkgs.addg (overlays/packages.nix).
{
  inputs,
  lib,
  ...
}: {
  perSystem = {
    system,
    pkgs,
    ...
  }: let
    # Flatten for packages output (only top-level derivations)
    flattenedPackages = let
      onlyForPlatform = pkg:
        if (pkg ? meta.platforms)
        then lib.elem system pkg.meta.platforms
        else true;

      collectDerivations = prefix: set:
        lib.concatMapAttrs (name: value:
          if lib.isDerivation value && onlyForPlatform value
          then {"${prefix}${name}" = value;}
          else if lib.isAttrs value && !lib.isDerivation value
          then collectDerivations "${prefix}${name}-" value
          else {})
        set;
    in
      collectDerivations "" pkgs.addg;
  in {
    # Same overlays and config as the hosts, so these share their store paths.
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [inputs.self.overlays.default];
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
      };
    };

    # Drop scope helpers: their `packages` function breaks `.#packages.<system>` lookups.
    legacyPackages = lib.filterAttrs (_: v: !builtins.isFunction v) pkgs.addg;
    packages = flattenedPackages;
  };
}
