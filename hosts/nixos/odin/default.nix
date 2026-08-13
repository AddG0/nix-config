#############################################################
#
#  odin - Server
#  NixOS running on Intel i9-13900H (20 cores), 32GB RAM
#
###############################################################
{
  inputs,
  lib,
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

    (map lib.custom.relativeToHosts (map (f: "common/optional/${f}") [
      "nixos/services/openssh.nix" # allow remote SSH access
      # "nixos/services/home-assistant-oci.nix"
      # "nixos/services/nginx.nix" # nginx
      "nixos/nix-access-token.nix"
      "nixos/services/kubernetes/clusters/asgard.nix"
      "nixos/services/nomad/clusters/midgard/server.nix"
      "nixos/services/gitlab-runner.nix"
    ]))
  ];

  nix.git-sync = {
    enable = true;
    # We stagger the schedule across thor odin and loki to keep the k3s cluster alive
    schedule = "03:20";
  };

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
    hostName = "odin";
    hostPlatform = "x86_64-linux";
    colmena.enable = true;
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
