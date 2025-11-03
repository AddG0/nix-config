#############################################################
#
#  zephy - Main Desktop
#  NixOS running on Ryzen 5 3600X, Radeon RX 5700 XT, 64GB RAM
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
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-gpu-amd
    # inputs.hardware.nixosModules.common-pc-ssd

    #################### Disk Layout ####################
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToHosts "common/disks/ext4-disk.nix")
    {
      _module.args = {
        disk = "/dev/sda"; # Main disk device
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
        "nixos/services/openssh.nix" # allow remote SSH access
        "nixos/nvtop.nix" # GPU monitor (not available in home-manager)
      ])
    ))
  ];

  hostSpec = {
    hostName = "k3s-prod-1-master-1";
    hostPlatform = "x86_64-linux";
  };

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  time.timeZone = "America/Chicago";

  # Configure bootloader for disko-managed partitions
  boot.loader = {
    grub = {
      enable = true;
      device = "/dev/sda";
    };
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd = {
    systemd.enable = true;
  };

  system.stateVersion = config.hostSpec.system.stateVersion;
}
