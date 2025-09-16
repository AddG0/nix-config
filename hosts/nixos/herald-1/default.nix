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
    inputs.lumenboard-player.nixosModules.lumenboard-player
    ./hardware-configuration.nix
    (lib.custom.scanPaths ./.)
    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

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
      #################### Desktop ####################
      # "common/optional/nixos/desktops/plasma6" # window manager - disabled for signage-only setup
      # "common/optional/nixos/services/greetd.nix" # display manager - disabled for headless signage
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

  # Signage Player Configuration
  services.lumenboard-player.instances = {
    tv-1 = {
      enable = true;
      cdnBaseUrl = "http://localhost:9000";
      tenantId = "acme-inc";
      screenId = "herald-1";
      environment.extra = {
        DISPLAY = ":1";
      };
    };
    tv-2 = {
      enable = true;
      cdnBaseUrl = "http://localhost:9000";
      tenantId = "acme-inc";
      screenId = "herald-2";
      port = 8089;
      environment.extra = {
        DISPLAY = ":0";
      };
    };
  };

  # X11 kiosk setup using recommended NixOS approach
  services.xserver = {
    enable = true;
    displayManager.lightdm = {
      enable = true;
      background = "#000000";
    };
    windowManager.openbox.enable = true;
    # Configure for dual display
    xrandrHeads = [ "DP-1" "HDMI-A-1" ];
  };

  services.displayManager = {
    defaultSession = "none+openbox";
    autoLogin = {
      enable = true;
      user = "lumenboard-player";
    };
  };

  # Hide mouse cursor for kiosk mode and disable screen power management
  services.xserver.displayManager.sessionCommands = ''
    # Configure dual display layout
    ${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --auto --output HDMI-A-1 --auto --right-of DP-1
    ${pkgs.xorg.xsetroot}/bin/xsetroot -cursor_name left_ptr
    ${pkgs.unclutter-xfixes}/bin/unclutter --timeout 1 --jitter 0 --ignore-scrolling --start-hidden --fork
    ${pkgs.xorg.xset}/bin/xset s off -dpms
  '';

  # Install kiosk tools
  environment.systemPackages = with pkgs; [
    unclutter-xfixes
    xorg.xsetroot
    xorg.xset
    xorg.xrandr
  ];

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "herald-1";
    hostPlatform = "x86_64-linux";
    colmena = {
      enable = true;
    };
  };

  system.stateVersion = config.hostSpec.system.stateVersion;

  time.timeZone = "America/Chicago";
}
