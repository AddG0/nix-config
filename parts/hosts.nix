# parts/hosts.nix - Host configurations
{inputs, ...}: {
  flake = {
    # Building configurations is available through `just rebuild` or `nixos-rebuild --flake .#hostname`
    nixosConfigurations = builtins.listToAttrs (
      map (host: {
        name = host;
        value = inputs.nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            outputs = inputs.self;
            lib = inputs.self.lib;
            isDarwin = false;
            nix-secrets = inputs.nix-secrets;
            nixvirt = inputs.nix-secrets;
          };
          modules = [
            ../hosts/nixos/${host}
            {
              virtualisation.diskSize = 20 * 1024;
              nix.registry.nixpkgs.flake = inputs.nixpkgs;
              nixpkgs.overlays = [
                (final: prev: {
                  nixos-generators = inputs.nixos-generators.packages.${final.system}.default;
                })
              ];
            }
          ];
        };
      }) (builtins.attrNames (builtins.readDir ../hosts/nixos))
    );

    darwinConfigurations = builtins.listToAttrs (
      map (host: {
        name = host;
        value = inputs.nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit inputs;
            outputs = inputs.self;
            lib = inputs.self.lib;
            isDarwin = true;
            nix-secrets = inputs.nix-secrets;
          };
          modules = [../hosts/darwin/${host}];
        };
      }) (builtins.attrNames (builtins.readDir ../hosts/darwin))
    );
  };
}
