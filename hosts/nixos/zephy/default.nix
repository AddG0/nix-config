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
    ./persistence.nix

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.asus-battery
    inputs.asus-numberpad-driver.nixosModules.default

    #################### Disk Layout ####################
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToHosts "common/disks/luks-btrfs-impermanence.nix")
    {_module.args.disk = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_2TB_S7YCNJ0L505492Y";}

    #################### Misc Inputs ####################

    (lib.custom.useSuite lib.custom.suites.gaming)
    (lib.custom.useSuite lib.custom.suites.hyprland)
    (lib.custom.useSuite lib.custom.suites.niri)
    (lib.custom.useSuite lib.custom.suites.plasma6)
    (with lib.custom.optional.hosts.nixos; [
      audio # pipewire and cli controls
      impermanence
      # nvtop # GPU monitor (not available in home-manager)
      onepassword
      # plymouth # fancy boot screen
      secureboot
    ])
    (with lib.custom.optional.hosts.nixos.hardware; [
      cachyos-kernel # CachyOS kernel
      openrazer # openrazer
      wooting # wooting keyboard
    ])
    (with lib.custom.optional.hosts.nixos.services; [
      automatic-timezoned
      bluetooth
      bt-proximity
      display-managers.silent-sddm
      earlyoom
      # home-assistant
      openssh # allow remote SSH access
      # openvpn # home VPN
      tailscale
    ])
  ];

  gaming.steam.sharedLibrary = "/srv/steam-library";

  programs.kdeconnect.enable = true;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  programs.captive-browser = {
    enable = true;
    interface = "wlp4s0";
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 20;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    # Tries the TPM first, then falls back to the passphrase; enrolled with systemd-cryptenroll.
    initrd.luks.devices.crypted.crypttabExtraOpts = ["tpm2-device=auto"];
  };

  security.allow-suspend.enable = true;

  yubikey.enable = true;

  # Host-specific Monitor Spec
  # If on hyprland, use `hyprctl monitors` to get monitor info.
  # https://wiki.hyprland.org/Configuring/Monitors/
  #           ------
  #        | HDMI-A-1 |
  #           ------
  #  ------   ------   ------
  # | DP-2 | | DP-1 | | DP-3 |
  #  ------   ------   ------
  display.monitors = [
    {
      output = "desc:AU Optronics 0x8E9D";
      width = 2560;
      height = 1600;
      refreshRate = 165;
      x = 555;
      y = 0;
      vrr = "on";
      primary = true;
      bitdepth = 10;
    }
    {
      output = "desc:BOE 0x0A68";
      width = 3840;
      height = 1100;
      refreshRate = 60;
      x = 0;
      y = 1600;
    }
  ];

  hostSpec = {
    hostName = "zephy";
    hostPlatform = "x86_64-linux";
    hostType = "laptop";
    # Decky and the console session run as gamer; addg stays the admin.
    primaryDesktopUsername = "gamer";
    users = ["gamer"];
  };

  # Fix bluetooth headphone disconnections - disable USB autosuspend for bluetooth adapter
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="13d3", ATTR{idProduct}=="3568", ATTR{power/control}="on"
  '';
}
