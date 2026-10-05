#############################################################
#
#  thor - Meigao F8BAC Mini PC
#  NixOS running on Ryzen AI 9 HX 370, Radeon 890M, 64GB RAM
#
###############################################################
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
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

    (with lib.custom.optional.hosts.nixos; [nix-secrets-deploy-key static-networking])
    (with lib.custom.optional.hosts.nixos.services; [
      kubernetes.clusters.asgard
      nomad.clusters.midgard.client
      openssh # allow remote SSH access
    ])
  ];

  nix.git-sync = {
    enable = true;
    # We stagger the schedule across thor odin and loki to keep the k3s cluster alive
    schedule = "03:40";
    rebootIfNeeded = true;
  };

  networking = {
    enableIPv6 = false;
    interfaces.enp195s0.wakeOnLan.enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "thor";
    hostPlatform = "x86_64-linux";
    colmena.enable = true;
    hostType = "server";
  };

  time.timeZone = "America/Chicago";
}
