#############################################################
#
#  ha-2 - Home Assistant mini PC
#  NixOS running on a DOKE MP200, i5-11400H, 16GB RAM, 512GB NVMe
#
###############################################################
{lib, ...}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)

    (with lib.custom.optional.hosts.nixos.services; [openssh])
  ];

  hostSpec = {
    hostName = baseNameOf ./.;
    hostPlatform = "x86_64-linux";
    # Not in nix-secrets yet.
    disableSops = true;
  };

  networking.networkmanager.enable = true;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
}
