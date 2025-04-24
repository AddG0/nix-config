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

      #################### Desktop ####################
      "common/optional/nixos/desktops/wayland" # window manager
      "common/optional/nixos/services/greetd.nix" # display manager
      "common/optional/nixos/vlc.nix" # media player
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

  services.dbus.enable = true;

  security.firewall.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "azuree";
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

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.kdePackages.xdg-desktop-portal-kde];
    wlr.enable = true;
    config.common.default = "kde";
  };

  # services.upower.enable = true;

  # needed unlock LUKS on secondary drives
  # use partition UUID
  # https://wiki.nixos.org/wiki/Full_Disk_Encryption#Unlocking_secondary_drives
  # environment.etc.crypttab.text = lib.optionalString (!config.hostSpec.isMinimal) ''
  #   cryptextra UUID=d90345b2-6673-4f8e-a5ef-dc764958ea14 /luks-secondary-unlock.key
  #   cryptvms UUID=ce5f47f8-d5df-4c96-b2a8-766384780a91 /luks-secondary-unlock.key
  # '';

  #hyprland border override example
  #  wayland.windowManager.hyprland.settings.general."col.active_border" = lib.mkForce "rgb(${config.stylix.base16Scheme.base0E});

  system.stateVersion = config.hostSpec.system.stateVersion;

  time.timeZone = "America/Chicago";

  # Add this to your system packages
  environment.systemPackages = with pkgs; [
    os-prober
    # other packages...
  ];
}
