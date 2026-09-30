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
    # inputs.disko.nixosModules.disko
    # (lib.custom.relativeToHosts "common/disks/dual-boot-disk.nix")
    # {
    #   _module.args = {
    #     # Use the full model name disk ID for the Crucial 4TB NVMe drive
    #     disk = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2323E6E05060";
    #     withSwap = false;
    #   };
    # }

    #################### Misc Inputs ####################

    (lib.custom.useSuite lib.custom.suites.docker)
    (lib.custom.useSuite lib.custom.suites.plasma6)
    (lib.custom.useSuite lib.custom.suites.gaming)
    (with lib.custom.optional.hosts.nixos; [
      # audio # pipewire and cli controls - using local audio.nix instead
      nvtop # GPU monitor (not available in home-manager)
      obs # obs
      onepassword
      # plymouth # fancy boot screen
    ])
    (with lib.custom.optional.hosts.nixos.hardware; [
      openrazer # openrazer
    ])
    (with lib.custom.optional.hosts.nixos.services; [
      bluetooth
      # home-assistant
      nginx # nginx
      openssh # allow remote SSH access
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

  yubikey.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "azuree";
    hostPlatform = "x86_64-linux";
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
    v4l-utils # For OBSBOT camera
  ];

  sops.secrets = {
    "nas-credentials" = {
      sopsFile = "${nix-secrets}/users/${config.hostSpec.primaryUsername}/nas-credentials.enc";
      format = "binary";
      neededForUsers = true;
    };
  };

  fileSystems."/mnt/videos" = {
    device = "//10.61.60.49/videos";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "uid=${toString config.users.users.${config.hostSpec.primaryUsername}.uid}"
      "gid=${toString config.users.users.${config.hostSpec.primaryUsername}.group}"
      "credentials=${config.sops.secrets.nas-credentials.path}"
    ];
  };

  time.timeZone = "America/Chicago";
}
