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

    #################### disk layout ####################
    #    inputs.disko.nixosmodules.disko
    #    (lib.custom.relativetohosts "common/disks/btrfs-disk.nix")
    #    {
    #      _module.args = {
    #        # use the full model name disk id for the 2tb nvme drive
    #        disk = "/dev/disk/by-id/nvme-acer_ssd_n5000_2tb_asbj53410202076";
    #        withswap = false;
    #      };
    #    }

    #################### misc inputs ####################

    (map lib.custom.relativeToHosts (map (f: "common/optional/${f}") [
      "nixos/services/openssh.nix" # allow remote ssh access
      "nixos/services/home-assistant-oci.nix"
      "nixos/services/nginx.nix" # nginx
    ]))
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

  security.firewall.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  hostSpec = {
    hostName = "ha-1";
    hostType = "server";
    hostPlatform = "x86_64-linux";
    colmena.enable = true;
  };

  time.timeZone = "America/Chicago";
}
