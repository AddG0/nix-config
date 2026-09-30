#############################################################
#
#  zephy - Main Desktop
#  NixOS running on Ryzen 5 3600X, Radeon RX 5700 XT, 64GB RAM
#
###############################################################
{
  inputs,
  lib,
  ...
}: {
  imports = lib.flatten [
    ./asus.nix
    ./graphics.nix
    ./hardware-configuration.nix
    ./battery.nix
    ./amd-performance.nix

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

    (lib.custom.useSuite lib.custom.suites.docker)
    (lib.custom.useSuite lib.custom.suites.awsvpnclient)
    (lib.custom.useSuite lib.custom.suites.plasma6)
    (lib.custom.useSuite lib.custom.suites.gaming)
    (with lib.custom.optional.hosts.nixos; [
      audio # pipewire and cli controls
      # nvtop # GPU monitor (not available in home-manager)
      onepassword
      # plymouth # fancy boot screen
    ])
    (with lib.custom.optional.hosts.nixos.development; [mysql])
    (with lib.custom.optional.hosts.nixos.hardware; [
      cachyos-kernel # CachyOS kernel
      openrazer # openrazer
      wooting # wooting keyboard
    ])
    (with lib.custom.optional.hosts.nixos.remote-desktop; [sunshine])
    (with lib.custom.optional.hosts.nixos.services; [
      automatic-timezoned
      bluetooth
      bt-proximity
      earlyoom
      greetd
      # home-assistant
      openssh # allow remote SSH access
      # openvpn # home VPN
      tailscale
    ])
    (with lib.custom.optional.hosts.nixos.virtualisation; [
      # docker
    ])
  ];

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

  security.allow-suspend.enable = true;

  yubikey.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "zephy";
    hostPlatform = "x86_64-linux";
    hostType = "laptop";
  };

  # Fix bluetooth headphone disconnections - disable USB autosuspend for bluetooth adapter
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="13d3", ATTR{idProduct}=="3568", ATTR{power/control}="on"
  '';
}
