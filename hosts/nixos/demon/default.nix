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

    (map lib.custom.relativeToHosts [
      #################### Required Configs ####################
      "common/core"

      #################### Host-specific Optional Configs ####################
      "common/optional/nixos/services/openssh.nix" # allow remote SSH access
      "common/optional/nixos/nvtop.nix" # GPU monitor (not available in home-manager)
      # "common/optional/nixos/audio.nix" # pipewire and cli controls - using local audio.nix instead
       "common/optional/nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
      # "common/optional/nixos/services/vscode-server.nix"
      # "common/optional/nixos/services/home-assistant"
      "common/optional/nixos/virtualisation/docker.nix" # docker
      # "common/optional/nixos/plymouth.nix" # fancy boot screen
      "common/optional/nixos/services/nginx.nix" # nginx
      # "common/optional/nixos/obs.nix" # obs
      "common/optional/nixos/hardware/openrazer.nix" # openrazer
      #################### Desktop ####################
      "common/optional/nixos/desktops/plasma6" # window manager
      "common/optional/nixos/services/greetd.nix" # display manager
      "common/optional/nixos/services/bluetooth.nix"
    ])
  ];

  programs.gpu-screen-recorder.enable = true;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  security.firewall.enable = true;

  services.deskflow-client = {
    enable = true;
    clientName = "demon";
    serverAddress = "192.168.110.160:24800";
  };

  services.obsbot-camera = {
    enable = true;
    devicePath = "/dev/video0";
    settings = {
      pan_absolute = 20000;
      tilt_absolute = -50000;
      zoom_absolute = 10;
      focus_automatic_continuous = 1;
    };
  };

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "demon";
    hostPlatform = "x86_64-linux";
  };

  hardware.xone.enable = true;

  environment.systemPackages = with pkgs; [
    cifs-utils
    v4l-utils # For OBSBOT camera
  ];

  sops.secrets = {
    "nas-credentials" = {
      sopsFile = "${nix-secrets}/secrets/users/${config.hostSpec.username}/nas-credentials.enc";
      format = "binary";
      neededForUsers = true;
    };
  };

  fileSystems."/mnt/videos" = {
    device = "//10.10.15.252/videos";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
      "vers=3.1.1"
      "soft"
      "timeo=5"
      "retry=0"
      "uid=${toString config.users.users.${config.hostSpec.username}.uid}"
      "gid=${toString config.users.users.${config.hostSpec.username}.group}"
      "credentials=${config.sops.secrets.nas-credentials.path}"
    ];
  };

  system.stateVersion = config.hostSpec.system.stateVersion;

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
