{
  description = "Minimal NixOS configuration for bootstrapping systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko.url = "github:nix-community/disko"; # Declarative partitioning and formatting
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (self) outputs;

    minimalSpecialArgs = isDarwin: {
      inherit inputs outputs;
      lib = nixpkgs.lib.extend (_self: _super: {
        custom = import ../lib {
          inherit (nixpkgs) lib;
          inherit isDarwin;
        };
      });
    };

    # This mkHost is way better: https://github.com/linyinfeng/dotfiles/blob/8785bdb188504cfda3daae9c3f70a6935e35c4df/flake/hosts.nix#L358
    newConfig = name: disk: useLuks: withSwap: swapSize: (
      let
        diskSpecPath =
          if useLuks
          then ../hosts/common/disks/btrfs-luks-disk.nix
          else ../hosts/common/disks/btrfs-disk.nix;
      in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = minimalSpecialArgs;
          modules = [
            inputs.disko.nixosModules.disko
            diskSpecPath
            #              ../hosts/common/disks/btrfs-disk.nix
            {
              _module.args = {
                inherit disk withSwap swapSize;
              };
            }
            ./minimal-configuration.nix
            ../hosts/nixos/${name}/hardware-configuration.nix

            {networking.hostName = name;}
          ];
        }
    );
  in {
    nixosConfigurations = {
      # host = newConfig "name" disk" "useLuks" "withSwap" "swapSize"
      # Swap size is in GiB
      zephy = newConfig "gusto" "/dev/nvme0n1" false false "0";

      # ghost = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   specialArgs = minimalSpecialArgs;
      #   modules = [
      #     inputs.disko.nixosModules.disko
      #     ../hosts/common/disks/ghost.nix
      #     ./minimal-configuration.nix
      #     { networking.hostName = "ghost"; }
      #     ../hosts/nixos/ghost/hardware-configuration.nix
      #   ];
      # };
    };
  };
}
