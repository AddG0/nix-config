#############################################################
#
#  demon - Main Desktop
#  NixOS running on Ryzen 9 9950X3D, RTX 5090, 128GB RAM
#
###############################################################
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    ./graphics.nix
    ./hardware-configuration.nix
    ./performance.nix
    ./sensors.nix
    # ./ai.nix
    ./audio
    ./media.nix
    ./awsvpn-home-dns-fix.nix
    ./mt7927.nix
    ./openrgb-schedule.nix

    (lib.custom.useSuite lib.custom.suites.hyprland)
    (lib.custom.useSuite lib.custom.suites.docker)
    (lib.custom.useSuite lib.custom.suites.awsvpnclient)
    (lib.custom.useSuite lib.custom.suites.gaming)
    (with lib.custom.optional.hosts; [nix-cache])
    (with lib.custom.optional.hosts.nixos; [
      audio # base pipewire + AirPods A2DP handling; ./audio layers demon-specific routing on top
      obs # obs
      onepassword
      # plymouth # fancy boot screen
      secureboot
      vr # monado OpenXR runtime (Bigscreen Beyond)
    ])
    (with lib.custom.optional.hosts.nixos.desktops; [
      # plasma6 # window manager
    ])
    (with lib.custom.optional.hosts.nixos.development; [
      ai-proxy
      # mysql
      # postgres
      # redis
    ])
    (with lib.custom.optional.hosts.nixos.hardware; [
      cachyos-kernel # CachyOS kernel
      flipperzero # flipper zero udev rules + qFlipper
      moza # MOZA R5 wheelbase (boxflat + udev)
      openrazer # openrazer
      openrgb # OpenRGB (motherboard SMBus set below)
      wacom-dial-scroll
      wooting # wooting keyboard
    ])
    (with lib.custom.optional.hosts.nixos.remote-desktop; [
      # sunshine
    ])
    (with lib.custom.optional.hosts.nixos.services; [
      bluetooth
      clamav
      earlyoom
      greetd
      lact # GPU overclocking/monitoring
      noctalia-greeter
      ollama
      openssh # allow remote SSH access
      tailscale # mesh VPN for secure remote access
    ])
  ];

  nix.git-sync = {
    enable = true;
  };

  # nix.remoteBuilder.enableClient = true;

  programs.gpu-screen-recorder.enable = true;

  services.hardware.openrgb = {
    # AMD FCH SMBus (i2c-piix4) is where the ASUS Aura controller lives.
    motherboard = "amd";
    # Bundles OpenRGBEffectsPlugin: software rainbow/spectrum over Direct mode,
    # since ASUS Aura addressable hardware effects don't work in OpenRGB.
    package = pkgs.openrgb-with-all-plugins;
  };

  programs.coolercontrol.enable = true;

  programs.kdeconnect.enable = true;

  networking = {
    networkmanager.enable = true;
    interfaces.enp12s0.wakeOnLan.enable = true;
  };

  # Press 'w' at boot menu to jump to Windows
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 20;
    };
    efi.canTouchEfiVariables = true;
    # A keypress in the window holds the menu open indefinitely.
    timeout = 1;
  };

  # qemu user-mode emulation so demon can build aarch64-linux derivations
  # (e.g. the heimdall Pi 5 SD image) without a remote builder.
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  # The board sets the staggered-spinup flag; without this the kernel probes all
  # 8 (empty) SATA ports serially at ~310ms each, inside the initrd.
  boot.kernelParams = ["libahci.ignore_sss=1"];

  boot.tmp.useTmpfs = true;
  # builds to disk-backed /var/tmp so a large one can't exhaust RAM (no swap here)
  systemd.services.nix-daemon.environment.TMPDIR = "/var/tmp";

  services.obsbot-camera = {
    enable = true;
    cameras.obsbot-tiny-2 = {
      vendorId = "3564";
      productId = "fef8";
      format = {
        width = 3840;
        height = 2160;
      };
      settings = {
        pan_absolute = 20000;
        tilt_absolute = -50000;
        zoom_absolute = 10;
        focus_automatic_continuous = 1;
      };
    };
  };

  security.allow-poweroff.enable = true;

  yubikey = {
    enable = true;
    autoScreenActivate = true;
    autoScreenUnlock = true;
    autoScreenLock = true;
  };

  services.greetd.autoLogin.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "demon";
    hostPlatform = "x86_64-linux";
    telemetry.enabled = true;
  };

  time.timeZone = "America/Chicago";
}
