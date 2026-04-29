#############################################################
#
#  kvasir - AI / Inference / GPU Server
#  NixOS running on Intel CPU with NVIDIA + AMD GPUs
#  TODO: Update hardware specs once installed
#
###############################################################
{
  inputs,
  lib,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)

    #################### Hardware ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    #################### Misc Inputs ####################

    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "nixos/services/openssh.nix" # allow remote SSH access
      ])
    ))
  ];

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
    interfaces.en01.wakeOnLan.enable = true;
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = lib.mkDefault 3;
  };

  security.firewall.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "kvasir";
    hostPlatform = "x86_64-linux";
    colmena = {
      enable = true;
    };
  };

  time.timeZone = "America/Chicago";
}
