#############################################################
#
#  kvasir - AI / Inference / GPU Server
#  NixOS running on i5-9600K, RTX 2080 Ti + 2x RX 580, 16GB RAM
#  Every GPU is on a x1 slot; the 2080 Ti trains at Gen2, so ~400MB/s to it.
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

    (map lib.custom.relativeToHosts (map (f: "common/optional/${f}") [
      "nixos/services/openssh.nix" # allow remote SSH access
      "nixos/nix-access-token.nix"
    ]))
  ];

  nix.git-sync = {
    enable = true;
    schedule = "04:00";
  };

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
    interfaces.eno1.wakeOnLan.enable = true;
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
    colmena.enable = true;
  };

  time.timeZone = "America/Chicago";
}
