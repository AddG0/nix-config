{
  inputs,
  lib,
  config,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)

    #################### hardware ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    #################### misc inputs ####################

    (with lib.custom.optional.hosts.nixos.services; [
      home-assistant-oci
      nginx # nginx
      openssh # allow remote ssh access
    ])
  ];

  services.homeAssistantOci = {
    autoUpdate.enable = true;
    hostName = "home-assistant-1.${config.hostSpec.domain}";
  };

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  hostSpec = {
    hostName = "ha-1";
    hostType = "server";
    hostPlatform = "x86_64-linux";
    colmena.enable = true;
  };

  time.timeZone = "America/Chicago";
}
