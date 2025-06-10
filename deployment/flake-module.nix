# deployment/flake-module.nix - Colmena deployment configuration
{inputs, lib, ...}: {
  flake = {
    # Colmena - remote deployment via SSH
    colmena = 
      {
        meta = {
          nixpkgs = import inputs.nixpkgs {system = "x86_64-linux";};
          specialArgs = {
            inherit inputs;
            self = inputs.self;
            lib = inputs.self.lib;
            isDarwin = false;
            nix-secrets = inputs.nix-secrets;
          };
        };
      }
      // builtins.mapAttrs (name: config: {
        deployment = {
          targetHost =
            if config.config.hostSpec.colmena.targetHost != ""
            then config.config.hostSpec.colmena.targetHost
            else config.config.hostSpec.hostName;
          targetUser = "root";
        };
        imports = config._module.args.modules;
      }) (lib.filterAttrs (
          name: value:
            value.config.nixpkgs.hostPlatform.system == "x86_64-linux"
            && value.config.hostSpec.colmena.enable
        )
        inputs.self.nixosConfigurations);
  };
}
