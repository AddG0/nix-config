#############################################################
#
#  base - extensible NixOS host scaffold.
#
#  Provides the minimal common bits any host needs: common/core, ssh +
#  tailscale for remote management, NetworkManager, hostSpec placeholders,
#  and isMinimal (so downstream flakes don't need a home/primary/<host>.nix).
#
#  Not deployable on its own (placeholder hostName etc.). Intended to be
#  extended from another flake:
#
#      nixosConfigurations.<host> =
#        nix-config.nixosConfigurations.base.extendModules {
#          modules = [
#            inputs.hardware.nixosModules.raspberry-pi-4
#            ./hosts/<host>            # hardware + host-specific module
#            ./modules/myapp.nix       # whatever app/desktop layer you add
#            { home-manager.users.<user>.imports = [ ./modules/hm.nix ]; }
#          ];
#        };
#
#  Override base's hostSpec/networking/etc. with lib.mkForce — everything
#  here is lib.mkDefault so downstream wins without ceremony.
#
###############################################################
{lib, ...}: {
  imports = lib.flatten [
    (map lib.custom.relativeToHosts (
      [
        "common/core"
      ]
      ++ (map (f: "common/optional/${f}") [
        "nixos/services/openssh.nix"
      ])
    ))
  ];

  hostSpec = {
    hostName = lib.mkDefault "base";
    hostPlatform = lib.mkDefault "x86_64-linux";
    hostType = lib.mkDefault "server";
    # No home/primary/base.nix exists; downstream flakes provide home-manager
    # config via modules rather than a per-host file, so skip the file lookup.
    isMinimal = lib.mkDefault true;
    # Throwaway flakes likely won't be in the secrets repo; downstream can
    # set this false explicitly if they wire sops up themselves.
    disableSops = lib.mkDefault true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking.networkmanager.enable = lib.mkDefault true;

  time.timeZone = lib.mkDefault "America/Chicago";

  # Placeholder so the OS config evaluates. Downstream overrides on real
  # hardware; the qemu-vm.nix profile overrides it for VM builds.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;
}
