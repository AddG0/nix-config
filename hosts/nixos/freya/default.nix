#############################################################
#
#  freya - Main Desktop
#  NixOS running on Ryzen 9 9900X3D, GTX 5090, 128GB RAM
#
###############################################################
{
  inputs,
  lib,
  ...
}: {
  imports = lib.flatten [
    inputs.stylix.nixosModules.stylix
    inputs.awsvpnclient-nix.nixosModules.default
    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    ./graphics.nix
    ./audio-workarounds.nix
    ./hardware-configuration.nix
    # ./ai.nix
    # ./audio
    ./media.nix

    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "nixos/hardware/cachyos-kernel.nix" # CachyOS kernel
        # "nixos/secureboot.nix"
        "nixos/services/openssh.nix" # allow remote SSH access
        "nixos/services/tailscale.nix" # mesh VPN for secure remote access
        "nixos/services/openvpn.nix"
        "nixos/audio.nix" # pipewire and cli controls - using local audio.nix instead
        "nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
        "nixos/virtualisation/docker.nix" # docker

        # "nixos/obs.nix" # obs
        "nixos/hardware/openrazer.nix" # openrazer
        "nixos/hardware/wooting.nix" # wooting keyboard
        "nixos/1password.nix"
        "nixos/services/bluetooth.nix"
        # "nixos/services/ollama.nix"
        # "nixos/services/clamav.nix"

        "nixos/remote-desktop/sunshine"

        "nixos/development/mysql.nix"

        "nixos/plymouth.nix" # fancy boot screen
        "nixos/services/greetd.nix"
        "nixos/desktops/hyprland"
      ])
    ))
  ];

  # AWS VPN Client with SAML support
  programs.awsvpnclient.enable = true;

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

  boot.kernelModules = ["ntsync"]; # NT sync primitives for Wine/Proton gaming performance

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "freya";
    hostPlatform = "x86_64-linux";
    telemetry.enabled = true;
    hostType = "laptop";
  };

  time.timeZone = "America/Chicago";

  # Runtime profile switching — no rebuild needed
  #   powerprofilesctl set power-saver|balanced|performance
  #   asusctl profile -P Quiet|Balanced|Performance
  services.power-profiles-daemon.enable = true;

  # Battery status reporting for desktop widgets
  services.upower.enable = true;
}
