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
    inputs.awsvpnclient-nix.nixosModules.default
    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################
    ./hardware-configuration.nix
    # ./ai.nix

    (map lib.custom.relativeToHosts (map (f: "common/optional/${f}") [
      "nixos/services/openssh.nix" # allow remote SSH access
    ]))
  ];

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
  };

  time.timeZone = "America/Chicago";
}
