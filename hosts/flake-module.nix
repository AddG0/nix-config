# hosts/flake-module.nix - Host configurations and format generation
{
  inputs,
  lib,
  ...
}: {
  flake = let
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

  # Format generation for NixOS hosts (ISO, VM, Docker, etc.)
  # Build with: nix build .#format-hostname
  perSystem = {system, ...}: let
    # Format to hosts mapping - each format specifies which hosts to build
    formatHosts = {
      # amazon = ["aws"];
      # azure = [];
      # cloudstack = [];
      # do = [];
      # docker = [];
      gce = ["gce"];
      # hyperv = [];
      # install-iso = [];
      # install-iso-hyperv = [];
      # iso = [];
      # kexec = [];
      # kexec-bundle = [];~
      # kubevirt = [];
      # linode = [];
      # lxc = [];
      # lxc-metadata = [];
      # openstack = [];
      # proxmox = [];
      # proxmox-lxc = [];
      # qcow = [];
      # qcow-efi = [];
      # raw = [];
      # raw-efi = [];
      # sd-aarch64 = [];
      # sd-aarch64-installer = [];
      # sd-x86_64 = [];
      # vagrant-virtualbox = [];
      # virtualbox = [];
      # vm = [];
      # vm-bootloader = [];
      # vm-nogui = [];
      # vmware = [];
    };

    # Generate a format-specific configuration for a NixOS host
    mkFormat = format: host: {
      name = "${format}-${host}";
      value = inputs.nixos-generators.nixosGenerate {
        inherit system format;
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
          inherit (inputs.self) lib;
          isDarwin = false;
        };
        modules = [./nixos/${host}];
      };
    };

    # Only generate formats for x86_64-linux (most formats are Linux-specific)
    formatPackages =
      if system == "x86_64-linux"
      then
        builtins.listToAttrs (
          lib.flatten (
            lib.mapAttrsToList (
              format: hosts:
                map (mkFormat format) hosts
            )
            formatHosts
          )
        )
      else {};
  in {
    packages = formatPackages;
  };
}
