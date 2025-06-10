# parts/packages.nix - Custom packages
{ inputs, ... }:
{
  perSystem = { config, self', inputs', pkgs, system, ... }: {
    # Add custom packages to be shared or upstreamed
    packages = 
      let
        lib = inputs.self.lib;
        # Get all packages from the directory
        allPackages = lib.packagesFromDirectoryRecursive {
          inherit (pkgs) callPackage;
          directory = ../pkgs/common;
        };
        
        # Flatten nested package structures
        flattenPackages = packages: 
          lib.concatMapAttrs (name: value:
            if lib.isDerivation value then
              { ${name} = value; }
            else if lib.isAttrs value then
              lib.mapAttrs' (subName: subValue: {
                name = "${name}-${subName}";
                value = subValue;
              }) (flattenPackages value)
            else
              {}
          ) packages;
      in
      flattenPackages allPackages;
  };
}
