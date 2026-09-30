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
    ./gamepadui-theme.nix
    ./graphics.nix
    ./hardware-configuration.nix

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    (lib.custom.useSuite lib.custom.suites.gaming)
    (with lib.custom.optional.hosts.nixos; [
      audio # pipewire
    ])
    (with lib.custom.optional.hosts.nixos.hardware; [
      cachyos-kernel # BORE + scx_lavd + ananicy
    ])
    (with lib.custom.optional.hosts.nixos.services; [
      bluetooth # wireless controller pairing
      earlyoom
      greetd # gamescope-session hangs off greetd
      openssh
    ])
  ];

  gaming.gamescopeSession.standalone = true;

  networking = {
    networkmanager.enable = true;
    interfaces.enp8s0.wakeOnLan.enable = true;
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 20;
    };
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd.systemd.enable = true;

  hostSpec = {
    hostName = "rig-pc";
    hostPlatform = "x86_64-linux";
    hostType = "desktop";
    disableSops = true;
  };

  time.timeZone = "America/Chicago";
}
