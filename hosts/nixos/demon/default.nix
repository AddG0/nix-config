#############################################################
#
#  demon - Main Desktop
#  NixOS running on Ryzen 9 9950X3D, RTX 5090, 128GB RAM
#
###############################################################
{
  config,
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
    (lib.custom.useSuite lib.custom.suites.niri)
    (lib.custom.useSuite lib.custom.suites.plasma6)
    (lib.custom.useSuite lib.custom.suites.docker)
    (lib.custom.useSuite lib.custom.suites.awsvpnclient)
    (lib.custom.useSuite lib.custom.suites.gaming)
    (with lib.custom.optional.hosts; [nix-cache])
    (with lib.custom.optional.hosts.nixos; [
      audio # base pipewire + AirPods A2DP handling; ./audio layers demon-specific routing on top
      determinate
      nix-builders.client
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
      # mysql
      # postgres
      # redis
    ])
    (with lib.custom.optional.hosts.nixos.hardware; [
      cachyos-kernel # CachyOS kernel
      flipperzero # flipper zero udev rules + qFlipper
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
      display-managers.silent-sddm
      earlyoom
      gpu-worker
      lact # GPU overclocking/monitoring
      ollama
      openssh # allow remote SSH access
      tailscale # mesh VPN for secure remote access
    ])
  ];

  nix.git-sync = {
    enable = true;
  };

  programs.kdeconnect.enable = true;

  programs.gpu-screen-recorder.enable = true;

  services.hardware.openrgb = {
    # AMD FCH SMBus (i2c-piix4) is where the ASUS Aura controller lives.
    motherboard = "amd";
    # Bundles OpenRGBEffectsPlugin: software rainbow/spectrum over Direct mode,
    # since ASUS Aura addressable hardware effects don't work in OpenRGB.
    package = pkgs.openrgb-with-all-plugins;
  };

  programs.coolercontrol.enable = true;

  networking = {
    networkmanager.enable = true;
    interfaces.enp12s0.wakeOnLan.enable = true;
    # asgard's ai-proxy reaches Ollama from the node IPs, as k3s masquerades pod egress.
    firewall.extraCommands = lib.concatMapStrings (ip: ''
      iptables -A nixos-fw -p tcp -s ${ip} --dport ${toString config.services.ollama.port} -j nixos-fw-accept
    '') ["10.61.60.10" "10.61.60.11" "10.61.60.12"];
  };

  # The desktop holds ~11 GiB of the 5090, so models stay under ~19 GB with a q8 KV cache.
  services.ollama = {
    host = "0.0.0.0";
    loadModels = ["qwen3.8:27b" "gemma4:31b" "gemma4:26b-a4b"];
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      # Each parallel slot reserves its own full-context KV cache.
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
    };
  };

  # Gemma 4 loops without a repeat penalty, and /v1 clients cannot send one.
  systemd.services.ollama-model-loader.script = lib.mkAfter ''
    ${config.services.ollama.package}/bin/ollama create gemma4:31b-rp -f ${pkgs.writeText "gemma4-31b-rp.Modelfile" ''
      FROM gemma4:31b
      PARAMETER repeat_penalty 1.1
      PARAMETER repeat_last_n 256
    ''}
  '';

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

  # Host-specific Monitor Spec
  #  ------   ------
  # | DP-2 | | DP-3 | ----
  # | ASUS | |  LG  | |HDMI-A-1|
  #  ------   ------  |(rot)|
  #                    ----
  display = {
    defaultMonitor.enable = false;
    monitors = [
      {
        output = "DP-2";
        name = "left";
        width = 3840;
        height = 2160;
        refreshRate = 144;
        x = 0;
        y = 0;
        bitdepth = 10;
        hdr = true;
      }
      {
        output = "DP-3";
        name = "main";
        width = 3840;
        height = 2160;
        refreshRate = 240;
        x = 3840;
        y = 0;
        primary = true;
        bitdepth = 10;
        hdr = true;
        # BT.2408 reference white; Hyprland's 80 makes SDR games dim next to HDR.
        sdrMaxLuminance = 203;
      }
      {
        output = "HDMI-A-1";
        name = "right";
        width = 3840;
        height = 2160;
        refreshRate = 120;
        scale = 1.2; # matches DP-3's logical px/mm so the portrait spans its true physical height
        transform = "270";
        x = 7680;
        y = -732; # 597mm panel overhangs the 392mm DP-3 by 205mm; ~56mm of that below its bottom edge
      }
    ];
  };

  hostSpec = {
    hostName = "demon";
    hostPlatform = "x86_64-linux";
    telemetry.enabled = true;
  };

  time.timeZone = "America/Chicago";
}
