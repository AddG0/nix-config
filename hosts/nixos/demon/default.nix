#############################################################
#
#  demon - Main Desktop
#  NixOS running on Ryzen 9 9900X3D, GTX 5090, 128GB RAM
#
###############################################################
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    inputs.stylix.nixosModules.stylix
    inputs.awsvpnclient-nix.nixosModules.default
    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    ./graphics.nix
    ./hardware-configuration.nix
    # ./ai.nix
    ./audio
    ./media.nix

    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "nixos/hardware/cachyos-kernel.nix" # CachyOS kernel
        "nixos/secureboot.nix"
        "nixos/services/openssh.nix" # allow remote SSH access
        "nixos/services/tailscale.nix" # mesh VPN for secure remote access
        # "nixos/nvtop.nix" # GPU monitor (not available in home-manager)
        # "nixos/audio.nix" # pipewire and cli controls - using local audio.nix instead
        "nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
        # "nixos/services/home-assistant"
        "nixos/virtualisation/docker.nix" # docker
        "nixos/libvirt.nix" # QEMU/KVM for VMs (macOS, etc)
        "nixos/services/nginx.nix" # nginx

        "nixos/obs.nix" # obs
        "nixos/hardware/openrazer.nix" # openrazer
        "nixos/hardware/wooting.nix" # wooting keyboard
        "nixos/1password.nix"
        "nixos/services/bluetooth.nix"
        "nixos/services/ollama.nix"
        "nixos/services/clamav.nix"
        "nixos/services/earlyoom.nix"

        # "nixos/remote-desktop/xrdp.nix"
        "nixos/remote-desktop/sunshine.nix"

        "nixos/development/mysql.nix"
        # "nixos/development/druid"

        # "nixos/plymouth.nix" # fancy boot screen
        "nixos/services/greetd.nix"
        # "nixos/desktops/plasma6" # window manager
        "nixos/desktops/hyprland"
      ])
    ))
  ];

  # nix.remoteBuilder.enableClient = true;

  # AWS VPN Client with SAML support
  programs.awsvpnclient.enable = true;

  programs.gpu-screen-recorder.enable = true;

  programs.kdeconnect.enable = true;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  # Press 'w' at boot menu to jump to Windows
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 20;
    };
    efi.canTouchEfiVariables = true;
  };

  security.firewall.enable = true;

  services.obsbot-camera = {
    enable = true;
    cameras.obsbot-tiny-2 = {
      # Watch both devices - apps may open either
      triggerPaths = [
        "/dev/v4l/by-id/usb-Remo_Tech_Co.__Ltd._OBSBOT_Tiny_2-video-index0"
        "/dev/v4l/by-id/usb-Remo_Tech_Co.__Ltd._OBSBOT_Tiny_2-video-index1"
      ];
      # PTZ controls are only on index0
      controlPath = "/dev/v4l/by-id/usb-Remo_Tech_Co.__Ltd._OBSBOT_Tiny_2-video-index0";
      settings = {
        pan_absolute = 20000;
        tilt_absolute = -50000;
        zoom_absolute = 10;
        focus_automatic_continuous = 1;
      };
    };
  };

  security.allow-poweroff.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "demon";
    hostPlatform = "x86_64-linux";
    telemetry.enabled = true;
  };

  time.timeZone = "America/Chicago";

  stylix = {
    enable = false;
    image = pkgs.fetchurl {
      url = "https://unsplash.com/photos/3l3RwQdHRHg/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzM2NTE4NDQ2fA&force=true";
      sha256 = "LtdnBAxruHKYE/NycsA614lL6qbGBlkrlj3EPNZ/phU=";
    };
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Original-Classic";
      size = 24; # adjust to your display
    };
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 0.8;
    };
    polarity = "dark";
  };
}
