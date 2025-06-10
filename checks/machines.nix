# checks/machines.nix - NixOS and Darwin configuration validation
{inputs, ...}: {
  perSystem = {
    lib,
    system,
    ...
  }: {
    checks = let
      # Machine checks - validate that configurations build
      machinesPerSystem = {
        aarch64-linux = []; # Add your aarch64-linux hosts here
        x86_64-linux = []; # Add your x86_64-linux hosts here
        x86_64-darwin = []; # Add your x86_64-darwin hosts here
        aarch64-darwin = []; # Add your aarch64-darwin hosts here
      };

      # NixOS machine checks
      nixosMachines = lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
        lib.genAttrs (machinesPerSystem.${system} or []) (
          name: inputs.self.nixosConfigurations.${name}.config.system.build.toplevel
        )
      );

      # Darwin machine checks
      darwinMachines = lib.mapAttrs' (n: lib.nameValuePair "darwin-${n}") (
        lib.genAttrs (machinesPerSystem.${system} or []) (
          name: inputs.self.darwinConfigurations.${name}.config.system.build.toplevel
        )
      );
    in
      nixosMachines // darwinMachines;
  };
}
