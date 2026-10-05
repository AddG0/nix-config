#############################################################
#
#  odin - Server
#  NixOS running on Intel i9-13900H (20 cores), 32GB RAM
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
      gitlab-runner
      # home-assistant-oci
      kubernetes.clusters.asgard
      # nginx # nginx
      nomad.clusters.midgard.server
      openssh # allow remote SSH access
      tailscale
    ])
  ];

  nix.git-sync = {
    enable = true;
    # We stagger the schedule across thor odin and loki to keep the k3s cluster alive
    schedule = "03:20";
    rebootIfNeeded = true;
  };

  services.tailscale = {
    useRoutingFeatures = "server";
    # Every *.addg0.com record and the UniFi resolver (.60.1) live on the Servers VLAN.
    extraSetFlags = ["--advertise-routes=10.61.60.0/24"];
  };

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
    hostName = "odin";
    hostPlatform = "x86_64-linux";
    colmena.enable = true;
    hostType = "server";
  };

  time.timeZone = "America/Chicago";

  # STOPGAP -- remove when this machine's CPU is replaced.
  # Physical cores 8 and 12 (logical 4-7) throw machine checks and panic the kernel.
  # Microcode is already current, so the damage is permanent; full diagnosis in
  # docs/guides/asgard-ha-migration.md.
  systemd.services.offline-degraded-cores = {
    description = "Offline degraded CPU cores 4-7";
    wantedBy = ["multi-user.target"];
    # kubelet reads CPU capacity once at startup, and would otherwise advertise 20.
    before = ["k3s.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for c in 4 5 6 7; do
        if [ "$(cat /sys/devices/system/cpu/cpu$c/online)" = 1 ]; then
          echo 0 > /sys/devices/system/cpu/cpu$c/online
        fi
      done
    '';
  };
}
