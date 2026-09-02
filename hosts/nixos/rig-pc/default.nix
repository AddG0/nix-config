#############################################################
#
#  rig-pc - Living-room console
#  NixOS running on Ryzen 9 7900X, RTX 4080, 64GB RAM
#  No desktop: greetd autologins straight into Steam Big
#  Picture under gamescope.
#
###############################################################
{
  inputs,
  lib,
  ...
}: {
  imports = lib.flatten [
    ./graphics.nix
    ./hardware-configuration.nix

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    (map lib.custom.relativeToHosts (map (f: "common/optional/${f}") [
      "nixos/hardware/cachyos-kernel.nix" # BORE + scx_lavd + ananicy
      "nixos/audio" # pipewire
      "nixos/services/bluetooth.nix" # wireless controller pairing
      "nixos/services/earlyoom.nix"
      "nixos/services/openssh.nix"

      "nixos/gaming" # steam, gamescope, gamemode, decky, xone
      "nixos/services/greetd.nix" # gamescope-session hangs off greetd
    ]))
  ];

  gaming.gamescopeSession.standalone = true;

  networking.networkmanager.enable = true;

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 20;
    };
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd.systemd.enable = true;

  security.firewall.enable = true;

  hostSpec = {
    hostName = "rig-pc";
    hostPlatform = "x86_64-linux";
    hostType = "desktop";
    disableSops = true;
  };

  time.timeZone = "America/Chicago";
}
