#############################################################
#
#  AWS EC2 Instance
#  NixOS running on AWS EC2
#
#  NOTE: This host does NOT use disko because the amazon-image
#  module from nixpkgs handles disk/filesystem configuration
#  automatically.
#
###############################################################
{
  lib,
  modulesPath,
  ...
}: {
  imports = lib.flatten [
    # EC2 config from nixpkgs - provides filesystem, bootloader, and cloud services
    "${modulesPath}/virtualisation/amazon-image.nix"

    (with lib.custom.optional.hosts.nixos.services; [
      openssh # Required for AWS access
    ])
  ];

  hostSpec = {
    hostName = "aws";
    hostPlatform = "x86_64-linux";
  };

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  time.timeZone = "America/Chicago";
}
