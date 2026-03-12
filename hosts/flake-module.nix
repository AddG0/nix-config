# hosts/flake-module.nix - Host configurations
{inputs, ...}: let
  # Helper function to read hosts from directory
  readHosts = dir:
    if builtins.pathExists dir
    then builtins.attrNames (builtins.readDir dir)
    else [];

  # Common special arguments for all systems
  commonSpecialArgs = {
    inherit inputs;
    inherit (inputs) self;
    inherit (inputs.self) lib;
    inherit (inputs) nix-secrets;
    isDarwin = false;
  };
in {
  flake = {
    # NixOS configurations
    # Build with: nixos-rebuild --flake .#hostname
    nixosConfigurations = let
      nixosHosts = readHosts ./nixos;
      mkNixOSConfig = host: {
        name = host;
        value = inputs.nixpkgs.lib.nixosSystem {
          specialArgs =
            commonSpecialArgs
            // {
              inherit (inputs) nixvirt;
            };
          modules = [./nixos/${host}];
        };
      };
    in
      builtins.listToAttrs (map mkNixOSConfig nixosHosts);

    # Darwin configurations
    # Build with: darwin-rebuild --flake .#hostname
    darwinConfigurations = let
      darwinHosts = readHosts ./darwin;
      mkDarwinConfig = host: {
        name = host;
        value = inputs.nix-darwin.lib.darwinSystem {
          specialArgs = commonSpecialArgs // {isDarwin = true;};
          modules = [./darwin/${host}];
        };
      };
    in
      builtins.listToAttrs (map mkDarwinConfig darwinHosts);
  };
}
