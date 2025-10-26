# checks/home-manager.nix - Home-manager configuration validation
_: {
  perSystem = {
    self',
    lib,
    ...
  }: {
    checks = let
      # Home-manager checks (if available)
      homeConfigurations = lib.mapAttrs' (
        name: config: lib.nameValuePair "home-manager-${name}" config.activation-script
      ) (self'.legacyPackages.homeConfigurations or {});
    in
      homeConfigurations;
  };
}
