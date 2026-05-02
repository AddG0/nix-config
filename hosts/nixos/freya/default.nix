#############################################################
#
#  freya - Main Desktop
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
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    ./graphics.nix
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
        # cachyos-kernel.nix intentionally NOT imported here — freya pins its
        # own LTS variant below to avoid 7.0-only regressions (NVIDIA jump_label,
        # xe DPMS wake). Other hosts (zephy/mini/demon) use cachyos-bore via
        # that shared import.
        # "nixos/secureboot.nix"
        "nixos/services/openssh.nix" # allow remote SSH access
        "nixos/services/tailscale.nix" # mesh VPN for secure remote access
        "nixos/services/openvpn.nix"
        "nixos/audio.nix" # pipewire and cli controls - using local audio.nix instead
        "nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
        "nixos/virtualisation/docker.nix" # docker
        "nixos/services/automatic-timezoned.nix"

        # "nixos/obs.nix" # obs
        "nixos/hardware/openrazer.nix" # openrazer
        "nixos/hardware/wooting.nix" # wooting keyboard
        "nixos/1password.nix"
        "nixos/services/bluetooth.nix"
        "nixos/services/ollama.nix"
        # "nixos/services/clamav.nix"

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

  programs.captive-browser = {
    enable = true;
    interface = "wlo1";
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

  # Pin to cachyos LTS (currently 6.18.x) on this host. 7.0 has two open
  # upstream regressions affecting freya's hardware (Panther Lake + RTX 5090):
  #   - NVIDIA open-driver jump_label suspend hang
  #     https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1117
  #   - xe DPMS / suspend wake failure on PTL/LNL/BMG
  #     https://gitlab.freedesktop.org/drm/xe/kernel/-/work_items/7791
  #     https://gitlab.freedesktop.org/drm/xe/kernel/-/work_items/7764
  # Switch back to cachyos-bore (the shared default) when both are fixed.
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts;

  boot.kernelModules = ["ntsync"]; # NT sync primitives for Wine/Proton gaming performance

  # RT721 (codec) + RT1320 (amp) on SoundWire link 3, SOF driver auto-detects.
  # All multi-speaker topologies fail (SmartMic DAI missing on this board) —
  # default function topology gives working 2ch. Needs upstream Razer RZ09-0581
  # quirk or SmartMic-free topology for full 4-speaker support.

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "freya";
    hostPlatform = "x86_64-linux";
    telemetry.enabled = true;
    hostType = "laptop";
  };

  # Runtime profile switching — no rebuild needed
  #   powerprofilesctl set power-saver|balanced|performance
  #   asusctl profile -P Quiet|Balanced|Performance
  services.power-profiles-daemon.enable = true;

  # 64GB swap file for hibernate support (RAM is 62GB)
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 64 * 1024;
    }
  ];

  boot.resumeDevice = "/dev/disk/by-uuid/8d35d53d-c3c1-4ed0-8a09-513992136532";

  # Battery status reporting for desktop widgets
  services.upower.enable = true;

  # More aggressive palm rejection for built-in touchpad —
  # lower values = lighter touches rejected as palms
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Touchpad Palm Threshold Override]
    MatchUdevType=touchpad
    AttrPalmSizeThreshold=70
    AttrPalmPressureThreshold=100
  '';
}
