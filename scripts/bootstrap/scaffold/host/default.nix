#############################################################
#
#  New host from `just bootstrap`; describe the machine here.
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
