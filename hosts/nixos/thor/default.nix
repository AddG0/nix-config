#############################################################
#
#  zephy - Main Desktop
#  NixOS running on Ryzen 5 3600X, Radeon RX 5700 XT, 64GB RAM
#
###############################################################
{
  inputs,
  nix-secrets,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Disk Layout ####################
    #    inputs.disko.nixosModules.disko
    #    (lib.custom.relativeToHosts "common/disks/btrfs-disk.nix")
    #    {
    #      _module.args = {
    #        # Use the full model name disk ID for the 2TB NVMe drive
    #        disk = "/dev/disk/by-id/nvme-Acer_SSD_N5000_2TB_ASBJ53410202076";
    #        withSwap = false;
    #      };
    #    }

    #################### Misc Inputs ####################

    (map lib.custom.relativeToHosts [
      #################### Required Configs ####################
      "common/core"

      #################### Host-specific Optional Configs ####################
      "common/optional/nixos/services/openssh.nix" # allow remote SSH access
      # "common/optional/nixos/services/home-assistant-oci.nix"
      # "common/optional/nixos/services/nginx.nix" # nginx
    ])
  ];

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  security.firewall.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "thor";
    hostPlatform = "x86_64-linux";
    colmena = {
      enable = true;
    };
  };

  system.stateVersion = config.hostSpec.system.stateVersion;

  time.timeZone = "America/Chicago";
}
