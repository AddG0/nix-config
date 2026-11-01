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

    #################### Misc Inputs ####################

    (with lib.custom.optional.hosts.nixos.services; [
      home-assistant-oci
      nginx # nginx
      openssh # allow remote SSH access
    ])
  ];

  services.homeAssistantOci.hostName = "home-assistant-eu.${config.hostSpec.domain}";

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  hostSpec = {
    hostName = "uk-box";
    hostType = "server";
    hostPlatform = "x86_64-linux";
    colmena.enable = true;
  };

  time.timeZone = "Europe/London";
}
