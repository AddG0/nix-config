# deployment/flake-module.nix - Colmena deployment configuration
{
  inputs,
  lib,
  ...
}: let
  # Set by `just deploy --ip`; silently inert under pure eval (getEnv returns "").
  overrideNode = builtins.getEnv "DEPLOY_TARGET_NODE";
  overrideHost = builtins.getEnv "DEPLOY_TARGET_HOST";
in {
  flake = {
    # Colmena - remote deployment via SSH
    colmena =
      {
        meta = {
          # Set nixpkgs to the deployment host's system (where colmena runs)
          # Actual builds will be delegated to remote builders based on derivation requirements
          nixpkgs = import inputs.nixpkgs {
            system = builtins.currentSystem;
          };
          specialArgs = {
            inherit inputs;
            inherit (inputs) self;
            inherit (inputs.self) lib;
            isDarwin = false;
            inherit (inputs) nix-secrets;
          };
        };
      }
      // builtins.mapAttrs (name: config: {
        deployment = {
          targetHost =
            if overrideHost != "" && overrideNode == name
            then overrideHost
            else if config.config.hostSpec.colmena.targetHost != ""
            then config.config.hostSpec.colmena.targetHost
            else config.config.hostSpec.hostName;
          targetUser = "root";
        };
        imports = config._module.args.modules;
      }) (lib.filterAttrs (
          _name: value:
            value.config.nixpkgs.hostPlatform.system
            == "x86_64-linux"
            && value.config.hostSpec.colmena.enable
        )
        inputs.self.nixosConfigurations);
  };
}
