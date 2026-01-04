#############################################################
#
#  demon - Main Desktop
#  NixOS running on Ryzen 9 9900X3D, GTX 5090, 128GB RAM
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
    inputs.stylix.nixosModules.stylix
    (lib.custom.scanPaths ./.)
    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-pc-ssd

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

    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "nixos/secureboot.nix"
        "nixos/services/openssh.nix" # allow remote SSH access
        "nixos/services/tailscale.nix" # mesh VPN for secure remote access
        # "nixos/nvtop.nix" # GPU monitor (not available in home-manager)
        # "nixos/audio.nix" # pipewire and cli controls - using local audio.nix instead
        "nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
        # "nixos/services/home-assistant"
        "nixos/virtualisation/docker.nix" # docker
        "nixos/services/nginx.nix" # nginx

        # "nixos/obs.nix" # obs
        "nixos/hardware/openrazer.nix" # openrazer
        "nixos/1password.nix"
        "nixos/services/bluetooth.nix"
        "nixos/services/ollama.nix"
        "nixos/services/clamav.nix"
        "nixos/services/opentelemetry-collector"

        "nixos/plymouth.nix" # fancy boot screen
        "nixos/services/greetd.nix"
        "nixos/desktops/plasma6" # window manager
      ])
    ))
  ];

  # AWS VPN Client with SAML support
  programs.awsvpnclient.enable = true;

  programs.gpu-screen-recorder.enable = true;

  programs.kdeconnect.enable = true;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  security.firewall.enable = true;

  # services.deskflow-client = {
  #   enable = true;
  #   clientName = "demon";
  #   serverAddress = "192.168.110.160:24800";
  # };

  services.obsbot-camera = {
    enable = true;
    devicePaths = ["/dev/video0"];
    settings = {
      pan_absolute = 20000;
      tilt_absolute = -50000;
      zoom_absolute = 10;
      focus_automatic_continuous = 1;
    };
  };

  security.allow-poweroff.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "demon";
    hostPlatform = "x86_64-linux";
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
