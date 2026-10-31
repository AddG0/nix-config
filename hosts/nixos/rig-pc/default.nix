#############################################################
#
#  rig-pc - Living-room console
#  NixOS running on Ryzen 9 7900X, RTX 4080, 64GB RAM
#  SDDM autologins into Steam Big Picture under gamescope;
#  "Switch to Desktop" drops into Plasma.
#
###############################################################
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    ./gamepadui-theme.nix
    ./graphics.nix
    ./hardware-configuration.nix

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    (lib.custom.useSuite lib.custom.suites.gaming)
    (lib.custom.useSuite lib.custom.suites.plasma6)
    (with lib.custom.optional.hosts.nixos; [
      audio # pipewire
      plymouth
    ])
    (with lib.custom.optional.hosts.nixos.hardware; [
      cachyos-kernel # BORE + scx_lavd + ananicy
      moza
    ])
    (with lib.custom.optional.hosts.nixos.services; [
      bluetooth # wireless controller pairing
      display-managers.silent-sddm
      earlyoom
      openssh
    ])
  ];

  gaming.steam.sharedLibrary = "/srv/steam-library";

  # Boot into Gaming Mode; Switch to Desktop still opens Plasma.
  desktops.loginSession = "gaming-mode";
  services.displayManager.autoLogin.enable = true;

  networking = {
    networkmanager.enable = true;
    interfaces.enp8s0.wakeOnLan.enable = true;
  };

  boot = {
    # The 7900X is Zen 4, and demon's identical pin means this kernel is already built there.
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-zen4;

    # SteamOS's own boot splash, from Valve's jupiter-hw-support via Jovian.
    plymouth = {
      theme = "steamos";
      themePackages = [pkgs.jovianPackages.steamdeck-hw-theme];
    };
    # Early KMS, or plymouth draws on the EFI framebuffer the 4080 takes over moments later.
    initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];
    # Plymouth skips simpledrm unless told, leaving it nothing to draw on until nvidia-drm's mode switch.
    kernelParams = ["plymouth.use-simpledrm"];

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  # Host-specific Monitor Spec
  # MSI MPG 491C OLED, native mode. Only reaches the per-game gamescope wrapper —
  # the session picks the EDID's preferred timing (3840x1080@60) unless told otherwise.
  display.monitors = [
    {
      output = "HDMI-A-1";
      name = "ultrawide";
      width = 5120;
      height = 1440;
      refreshRate = 144;
      primary = true;
    }
  ];

  hostSpec = {
    hostName = "rig-pc";
    hostPlatform = "x86_64-linux";
    hostType = "desktop";
    disableSops = true;
    # Autologin, Decky and the CSS theme run as gamer; addg stays the admin.
    primaryDesktopUsername = "gamer";
    users = ["gamer"];
  };

  time.timeZone = "America/Chicago";
}
