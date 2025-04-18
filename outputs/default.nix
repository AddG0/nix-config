{
  self,
  nixpkgs,
  pre-commit-hooks,
  home-manager,
  nix-darwin,
  nur-ryan4yin,
  nix-homebrew,
  nix-secrets,
  sops-nix,
  nixos-generators,
  spicetify-nix,
  ...
} @ inputs: let
  inherit (self) outputs;

  # ========== Extend lib with lib.custom ==========
  # NOTE: This approach allows lib.custom to propagate into hm
  # see: https://github.com/nix-community/home-manager/pull/3454
  lib = nixpkgs.lib.extend (self: super: {custom = import ../lib {inherit (nixpkgs) lib;};});

  # Helper function to generate a set of attributes for each system
  forAllSystems = nixpkgs.lib.genAttrs [
    "x86_64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  # Packages, checks, devShells and formatter for all systems
  packages = forAllSystems (system: let
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    checks = import ../checks {inherit inputs system pkgs;};
    devShells = import ./devshell.nix {inherit self nixpkgs;} system;
    formatter = pkgs.alejandra;
  });

  # List of all available formats
  formats = [
    "amazon"
    "azure"
    "cloudstack"
    "do"
    "docker"
    "gce"
    "hyperv"
    "install-iso"
    "install-iso-hyperv"
    "iso"
    "kexec"
    "kexec-bundle"
    "kubevirt"
    "linode"
    "lxc"
    "lxc-metadata"
    "openstack"
    "proxmox"
    "proxmox-lxc"
    "qcow"
    "qcow-efi"
    "raw"
    "raw-efi"
    "sd-aarch64"
    "sd-aarch64-installer"
    "sd-x86_64"
    "vagrant-virtualbox"
    "virtualbox"
    "vm"
    "vm-bootloader"
    "vm-nogui"
    "vmware"
  ];

  # Generate a format-specific configuration for a NixOS host
  mkFormat = format: host: system: {
    ${host} = nixos-generators.nixosGenerate {
      inherit system format;
      specialArgs = {
        inherit inputs outputs lib;
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

  # Generate format-specific configs for each NixOS host
  mkFormatConfigs = format: hosts: system: lib.foldl (acc: set: acc // set) {} (lib.map (host: mkFormat format host system) hosts);
in {
  #
  # ========= Host Configurations =========
  #
  # Building configurations is available through `just rebuild` or `nixos-rebuild --flake .#hostname`
  nixosConfigurations = builtins.listToAttrs (
    map (host: {
      name = host;
      value = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs lib;
          isDarwin = false;
          nix-secrets = inputs.nix-secrets;
        };
        modules = [
          ../hosts/nixos/${host}
          {
            virtualisation.diskSize = 20 * 1024;
            nix.registry.nixpkgs.flake = nixpkgs;
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
      value = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs outputs lib;
          isDarwin = true;
          nix-secrets = inputs.nix-secrets;
        };
        modules = [../hosts/darwin/${host}];
      };
    }) (builtins.attrNames (builtins.readDir ../hosts/darwin))
  );

  # Generate format-specific configurations for each format
  formatConfigurations = builtins.listToAttrs (
    map (format: {
      name = format;
      value = builtins.listToAttrs (
        map (host: {
          name = host;
          value = mkFormat format host "x86_64-linux";
        }) (builtins.attrNames (builtins.readDir ../hosts/nixos))
      );
    })
    formats
  );

  #
  # ========= Overlays =========
  #
  # Custom modifications/overrides to upstream packages.
  overlays = import ../overlays {
    inherit inputs;
  };

  #
  # ========= Packages =========
  #
  # Add custom packages to be shared or upstreamed.
  # packages = forAllSystems (
  #   system: let
  #     pkgs = import nixpkgs {
  #       inherit system;
  #       overlays = [self.overlays.default];
  #     };
  #   in
  #     lib.packagesFromDirectoryRecursive {
  #       callPackage = lib.callPackageWith pkgs;
  #       directory = ../pkgs/common;
  #     }
  # );

  # # Colmena - remote deployment via SSH
  # colmena =
  #   {
  #     meta =
  #       (
  #         let
  #           system = "x86_64-linux";
  #         in {
  #           # colmena's default nixpkgs & specialArgs
  #           nixpkgs = import nixpkgs {inherit system;};
  #           specialArgs = specialArgs;
  #         }
  #       )
  #       // {
  #         # per-node nixpkgs & specialArgs
  #         nodeNixpkgs = lib.attrsets.mergeAttrsList (map (it: it.colmenaMeta.nodeNixpkgs or {}) nixosSystemValues);
  #         nodeSpecialArgs = lib.attrsets.mergeAttrsList (map (it: it.colmenaMeta.nodeSpecialArgs or {}) nixosSystemValues);
  #       };
  #   }
  #   // lib.attrsets.mergeAttrsList (map (it: it.colmena or {}) nixosSystemValues);

  # Eval Tests for all NixOS & darwin systems.
  # evalTests = lib.lists.all (it: it.evalTests == {}) allSystemValues;

  checks = forAllSystems (system: packages.${system}.checks);
  devShells = forAllSystems (system: packages.${system}.devShells);
  formatter = forAllSystems (system: packages.${system}.formatter);
}
