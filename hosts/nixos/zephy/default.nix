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
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.asus-battery

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
        "nixos/services/openssh.nix" # allow remote SSH access
        # "nixos/nvtop.nix" # GPU monitor (not available in home-manager)
        "nixos/audio.nix" # pipewire and cli controls
        "nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
        # "nixos/services/vscode-server.nix"
        # "nixos/services/home-assistant.nix"
        "nixos/virtualisation/docker.nix" # docker
        # "nixos/plymouth.nix" # fancy boot screen
        "nixos/services/bluetooth.nix"

        #################### Desktop ####################
        "nixos/desktops/plasma6" # window manager
        # "nixos/services/greetd.nix" # display manager
      ])
    ))
  ];

  services.system-git-sync = {
    enable = true;
    notifications.enable = true;
  };

  programs.awsvpnclient.enable = true;

  services.bt-proximity = {
    enable = true;
    deviceServiceUuidFile = "${config.hostSpec.home}/.config/sops/whoop_file"; # TODO: move to actual secret
  };
  
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
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  security.firewall.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "zephy";
    hostPlatform = "x86_64-linux";
  };

  #   # Enable CUPS to print documents.
  # services.printing.enable = true;

  # # Enable sound with pipewire.
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

  services.upower.enable = true;

  # Enable IP-based automatic timezone detection
  services.ip-timezone.enable = true;

  system.stateVersion = config.hostSpec.system.stateVersion;
}
