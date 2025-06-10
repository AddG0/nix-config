# Host configurations module - includes all heavy dependencies
{ inputs, ... }:

let
  inherit (inputs) nixpkgs home-manager nix-darwin;
  
  # Extended lib with custom functions
  lib = nixpkgs.lib.extend (self: super: {
    custom = import ../lib { inherit (nixpkgs) lib; };
  });
in

{
  flake = {
    # NixOS system configurations
    nixosConfigurations = builtins.listToAttrs (
      map (host: {
        name = host;
        value = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs lib;
            outputs = inputs.self;
            isDarwin = false;
            nix-secrets = inputs.nix-secrets;
            nixvirt = inputs.nixvirt;
          };
          modules = [
            ../hosts/nixos/${host}
            {
              virtualisation.diskSize = 20 * 1024;
              nix.registry.nixpkgs.flake = nixpkgs;
              nixpkgs.overlays = [
                inputs.self.overlays.default
                (final: prev: {
                  nixos-generators = inputs.nixos-generators.packages.${final.system}.default;
                })
              ];
            }
          ];
        };
      }) (builtins.attrNames (builtins.readDir ../hosts/nixos))
    );

    # Darwin system configurations  
    darwinConfigurations = builtins.listToAttrs (
      map (host: {
        name = host;
        value = nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit inputs lib;
            outputs = inputs.self;
            isDarwin = true;
            nix-secrets = inputs.nix-secrets;
          };
          modules = [
            ../hosts/darwin/${host}
            {
              nixpkgs.overlays = [ inputs.self.overlays.default ];
            }
          ];
        };
      }) (builtins.attrNames (builtins.readDir ../hosts/darwin))
    );

    # Colmena deployment configurations
    colmena = 
      {
        meta = {
          nixpkgs = import nixpkgs { system = "x86_64-linux"; };
          specialArgs = {
            inherit inputs lib;
            outputs = inputs.self;
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
            value.config.nixpkgs.hostPlatform.system
            == "x86_64-linux"
            && value.config.hostSpec.colmena.enable
        )
        inputs.self.nixosConfigurations);
  };

  # Generate format-specific configurations for hosts
  perSystem = { system, ... }: let
    # List of all available formats
    formats = [
      "amazon" "azure" "cloudstack" "do" "docker" "gce" "hyperv"
      "install-iso" "install-iso-hyperv" "iso" "kexec" "kexec-bundle"
      "kubevirt" "linode" "lxc" "lxc-metadata" "openstack" "proxmox"
      "proxmox-lxc" "qcow" "qcow-efi" "raw" "raw-efi" "sd-aarch64"
      "sd-aarch64-installer" "sd-x86_64" "vagrant-virtualbox"
      "virtualbox" "vm" "vm-bootloader" "vm-nogui" "vmware"
    ];

    # Generate a format-specific configuration for a NixOS host
    mkFormat = format: host: {
      ${host} = inputs.nixos-generators.nixosGenerate {
        inherit system format;
        specialArgs = {
          inherit inputs lib;
          outputs = inputs.self;
          isDarwin = false;
        };
        modules = [
          ../hosts/nixos/${host}
          {
            virtualisation.diskSize = 20 * 1024;
            nix.registry.nixpkgs.flake = nixpkgs;
          }
        ];
      };
    };
  in {
    # Add format-specific packages if needed
    packages = {
      # Example: iso configurations
      # Uncomment and customize as needed
      # inherit (inputs.self.nixosConfigurations) iso;
    };
  };
} 