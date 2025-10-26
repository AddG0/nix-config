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
    ./disk.nix

    #################### Misc Inputs ####################
    (map lib.custom.relativeToHosts [
      #################### Required Configs ####################
      "common/core"

      #################### Host-specific Optional Configs ####################
      "common/optional/nixos/services/openssh.nix" # allow remote SSH access
      # "common/optional/nixos/nvtop.nix" # GPU monitor (not available in home-manager)
    ])
  ];

  hostSpec = {
    hostName = "stark";
    hostPlatform = "x86_64-linux";
    disableSops = true;
  };

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  time.timeZone = "America/Chicago";

  boot.loader = {
    grub = {
      enable = true;
      device = "/dev/sda";
      useOSProber = true;
    };
    # systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd = {
    systemd.enable = true;
  };

  system.stateVersion = config.hostSpec.system.stateVersion;
}
