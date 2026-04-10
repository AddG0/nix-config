#############################################################
#
#  mini - Meigao F8BAC Mini PC
#  NixOS running on Ryzen AI 9 HX 370, Radeon 890M, 64GB RAM
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
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    ./hardware-configuration.nix
    # ./ai.nix

    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "nixos/hardware/cachyos-kernel.nix" # CachyOS kernel
        "nixos/services/openssh.nix" # allow remote SSH access
        "nixos/services/tailscale.nix" # mesh VPN for secure remote access
        "nixos/audio.nix" # pipewire and cli controls
        "nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
        "nixos/virtualisation/docker.nix" # docker

        # "nixos/obs.nix" # obs
        "nixos/hardware/openrazer.nix" # openrazer
        "nixos/hardware/wooting.nix" # wooting keyboard
        "nixos/hardware/fprintd.nix" # fingerprint reader (Realtek 2541:fa03)
        "nixos/1password.nix"
        "nixos/services/bluetooth.nix"
        "nixos/services/openvpn.nix"
        "nixos/services/gitlab-runner.nix"

        "nixos/development/mysql.nix"
        # "nixos/development/druid"

        # "nixos/plymouth.nix" # fancy boot screen
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

  boot.initrd = {
    systemd.enable = true;
  };

  # MT7925 combo WiFi+BT — BT side exposed over USB
  boot.kernelModules = ["btusb"];
  hardware.firmware = [pkgs.linux-firmware];

  hostSpec = {
    hostName = "mini";
    hostPlatform = "x86_64-linux";
    telemetry.enabled = true;
    networking.homeWifiSsids = ["Karen_5G-1"];
  };

  time.timeZone = "America/Chicago";
}
