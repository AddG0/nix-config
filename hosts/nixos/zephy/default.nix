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
    inputs.awsvpnclient-nix.nixosModules.default
    ./asus.nix
    ./graphics.nix
    ./hardware-configuration.nix
    ./battery.nix

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.asus-battery
    inputs.asus-numberpad-driver.nixosModules.default

    #################### Disk Layout ####################
    # inputs.disko.nixosModules.disko
    # (lib.custom.relativeToHosts "common/disks/dual-boot-disk.nix")
    # {
    #   _module.args = {
    #     # Use the full model name disk ID
    #     disk = "/dev/disk/by-id/nvme-SAMSUNG_MZVL22T0HBLB-00B00_S677NF0RC06854";
    #     withSwap = false;
    #   };
    # }

    #################### Misc Inputs ####################

    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "nixos/hardware/cachyos-kernel.nix" # CachyOS kernel
        "nixos/services/openssh.nix" # allow remote SSH access
        # "nixos/nvtop.nix" # GPU monitor (not available in home-manager)
        "nixos/audio.nix" # pipewire and cli controls
        "nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
        # "nixos/services/home-assistant.nix"
        # "nixos/virtualisation/docker.nix"
        # "nixos/plymouth.nix" # fancy boot screen
        "nixos/services/bluetooth.nix"
        "nixos/services/bt-proximity.nix"
        "nixos/services/automatic-timezoned.nix"
        "nixos/1password.nix"
        "nixos/hardware/openrazer.nix" # openrazer
        "nixos/development/mysql.nix"

        #################### Desktop ####################
        "nixos/desktops/hyprland"
        "nixos/services/greetd.nix"

        #################### Remote Desktop ####################
        "nixos/remote-desktop/sunshine"
        "nixos/services/tailscale.nix"
      ])
    ))
  ];

  nix.git-sync = {
    enable = false;
    notifications.enable = true;
  };

  programs.awsvpnclient.enable = true;

  programs.kdeconnect.enable = true;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  programs.captive-browser = {
    enable = true;
    interface = "wlp4s0";
  };

  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 20;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  security.firewall.enable = true;
  security.allow-suspend.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "zephy";
    hostPlatform = "x86_64-linux";
    hostType = "laptop";
  };
}
