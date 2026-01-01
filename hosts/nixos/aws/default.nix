#############################################################
#
#  AWS EC2 Instance
#  NixOS running on AWS EC2
#
###############################################################
{
  inputs,
  lib,
  config,
  ...
}: {
  imports = lib.flatten [
    #################### Every Host Needs This ####################
    ./hardware-configuration.nix

    #################### Hardware Modules ####################
    # AWS instances don't need specific hardware modules

    #################### Disk Layout ####################
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToHosts "common/disks/ext4-disk.nix")
    {
      _module.args = {
        disk = "/dev/xvda"; # Standard AWS root device
        withSwap = true;
      };
    }

    #################### Misc Inputs ####################
    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "nixos/services/openssh.nix" # Required for AWS access
      ])
    ))
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

  # Required for AWS EC2 instances
  boot = {
    loader.grub = {
      enable = lib.mkDefault true;
      # Let disko handle the device configuration
      device = lib.mkDefault "nodev";
      efiSupport = lib.mkDefault false;
      useOSProber = lib.mkDefault false;
    };
    initrd = {
      systemd.enable = lib.mkDefault true;
    };
  };
}
