#############################################################
#
#  loki - Server
#  NixOS running on Intel i9-13900H (20 cores), 64GB RAM
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

    (with lib.custom.optional.hosts.nixos; [nix-secrets-deploy-key static-networking])
    (with lib.custom.optional.hosts.nixos.services; [
      home-assistant-oci
      kubernetes.clusters.asgard
      # n8n # n8n
      nginx # nginx
      nomad.clusters.midgard.client
      openssh # allow remote SSH access
      tailscale
    ])
  ];

  nix.git-sync = {
    enable = true;
    # We stagger the schedule across thor odin and loki to keep the k3s cluster alive
    schedule = "03:00";
  };

  services.tailscale = {
    useRoutingFeatures = "server";
    # Every *.addg0.com record and the UniFi resolver (.60.1) live on the Servers VLAN.
    extraSetFlags = ["--advertise-routes=10.61.60.0/24"];
  };

  services.homeAssistantOci.autoUpdate.enable = true;

  networking = {
    enableIPv6 = false;
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
    hostName = "loki";
    hostPlatform = "x86_64-linux";
    colmena.enable = true;
    hostType = "server";
  };

  time.timeZone = "America/Chicago";
}
