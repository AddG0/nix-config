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
    #     # Use the full model name disk ID
    #     disk = "/dev/disk/by-id/nvme-SAMSUNG_MZVL22T0HBLB-00B00_S677NF0RC06854";
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
      # "common/optional/nixos/services/nginx.nix" # nginx
      "common/optional/nixos/obs.nix" # obs
      #################### Desktop ####################
      "common/optional/nixos/desktops/wayland" # window manager
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
  security.firewall.allowedTCPPorts = [4242]; # Lan mouse temporarily here, will move later

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "azuree";
    hostPlatform = "x86_64-linux";
  };

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
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "uid=${toString config.users.users.${config.hostSpec.username}.uid}"
      "gid=${toString config.users.users.${config.hostSpec.username}.group}"
      "credentials=${config.sops.secrets.nas-credentials.path}"
    ];
  };

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # Uncomment if you use JACK applications
    # jack.enable = true;

    # Configure PipeWire to support high sample rates
    extraConfig.pipewire."99-hifi.conf" = {
      "context.properties" = {
        "default.clock.rate" = 96000;
        "default.clock.allowed-rates" = [44100 48000 88200 96000 192000];
        "resample.quality" = 10;
      };
    };
  };

  system.stateVersion = config.hostSpec.system.stateVersion;

  time.timeZone = "America/Chicago";
}
