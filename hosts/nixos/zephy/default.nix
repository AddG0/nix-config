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
    #################### Hardware ####################
    ./hardware-configuration.nix
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.asus-battery
    ./graphics.nix

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
    inputs.stylix.nixosModules.stylix

    (map lib.custom.relativeToHosts [
      #################### Required Configs ####################
      "common/core"

      #################### Host-specific Optional Configs ####################
      "common/optional/nixos/services/openssh.nix" # allow remote SSH access
      "common/optional/nixos/nvtop.nix" # GPU monitor (not available in home-manager)
      "common/optional/nixos/audio.nix" # pipewire and cli controls
      "common/optional/nixos/gaming.nix" # steam, gamescope, gamemode, and related hardware
      "common/optional/nixos/hyprland.nix" # window manager
      "common/optional/nixos/services/vscode-server.nix"
      # "common/optional/nixos/services/home-assistant.nix"
      # "common/optional/nixos/virtualisation/docker.nix" # docker
      # "common/optional/nixos/services/pterodactyl" # pterodactyl
      # "common/optional/nixos/plymouth.nix" # fancy boot screen

      #################### Desktop ####################
      "common/optional/nixos/services/greetd.nix" # display manager
      "common/optional/nixos/hyprland.nix" # window manager
      "common/optional/nixos/file-managers/dolphin.nix" # file manager
      "common/optional/nixos/vlc.nix" # media player
      "common/optional/nixos/wayland.nix" # wayland components and pkgs not available in home-manager
      # "common/optional/nixos/desktops/plasma"
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

  xdg.portal = {
    enable = true;
    wlr.enable = true;  # for Wayland compositors like Hyprland
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
    ];
  };

  security.firewall.enable = true;

  # services.xserver.enable = true;
  # services.xserver.displayManager.lightdm.enable = true;
  # services.xserver.desktopManager.cinnamon.enable = true;

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
  # security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # needed unlock LUKS on secondary drives
  # use partition UUID
  # https://wiki.nixos.org/wiki/Full_Disk_Encryption#Unlocking_secondary_drives
  # environment.etc.crypttab.text = lib.optionalString (!config.hostSpec.isMinimal) ''
  #   cryptextra UUID=d90345b2-6673-4f8e-a5ef-dc764958ea14 /luks-secondary-unlock.key
  #   cryptvms UUID=ce5f47f8-d5df-4c96-b2a8-766384780a91 /luks-secondary-unlock.key
  # '';

  #TODO:(stylix) move this stuff to separate file but define theme itself per host
  # host-wide styling
  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url = "https://unsplash.com/photos/3l3RwQdHRHg/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzM2NTE4NDQ2fA&force=true";
      sha256 = "LtdnBAxruHKYE/NycsA614lL6qbGBlkrlj3EPNZ/phU=";
    };
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    cursor = {
      package = pkgs.catppuccin-cursors.mochaDark;
      name = "Catppuccin-Mocha-Dark";
      size = 24; # or 16, 20, 32, etc. — whatever looks right on your display
    };
    #     fonts = {
    #monospace = {
    #    package = pkgs.foo;
    #    name = "";
    #};
    #sanSerif = {
    #    package = pkgs.foo;
    #    name = "";
    #};
    #serif = {
    #    package = pkgs.foo;
    #    name = "";
    #};
    #    sizes = {
    #        applications = 12;
    #        terminal = 12;
    #        desktop = 12;
    #        popups = 10;
    #    };
    #};
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 0.8;
    };
    polarity = "dark";
    # program specific exclusions
    #targets.foo.enable = false;
  };
  #hyprland border override example
  #  wayland.windowManager.hyprland.settings.general."col.active_border" = lib.mkForce "rgb(${config.stylix.base16Scheme.base0E});

  system.stateVersion = config.hostSpec.system.stateVersion;



  services.automatic-timezoned.enable = true;

  # Add this to your system packages
  environment.systemPackages = with pkgs; [
    os-prober
    # other packages...
  ];
}
