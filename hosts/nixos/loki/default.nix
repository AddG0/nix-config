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

    (map lib.custom.relativeToHosts [
      #################### Required Configs ####################
      "common/core"

      #################### Host-specific Optional Configs ####################
      "common/optional/nixos/services/openssh.nix" # allow remote SSH access
      "common/optional/nixos/nvtop.nix" # GPU monitor (not available in home-manager)
      "common/optional/nixos/audio.nix" # pipewire and cli controls
      "common/optional/nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
      "common/optional/nixos/services/vscode-server.nix"
      # "common/optional/nixos/services/home-assistant.nix"
      "common/optional/nixos/virtualisation/docker.nix" # docker
      # "common/optional/nixos/plymouth.nix" # fancy boot screen
      "common/optional/nixos/services/nginx.nix" # nginx
      "common/optional/nixos/obs.nix" # obs
      "common/optional/nixos/hardware/openrazer.nix" # openrazer
      #################### Desktop ####################
      "common/optional/nixos/desktops/hyprland" # window manager
      "common/optional/nixos/services/greetd.nix" # display manager
      "common/optional/nixos/services/bluetooth.nix"
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
    hostName = "loki";
    hostPlatform = "x86_64-linux";
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
  ];

  system.stateVersion = config.hostSpec.system.stateVersion;

  time.timeZone = "America/Chicago";
}
