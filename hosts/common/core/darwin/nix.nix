{
  inputs,
  config,
  outputs,
  lib,
  pkgs,
  ...
}: {
  nix = {
    gc.automatic = true;

    # Garbage Collection
    gc = {
      options = "--delete-older-than 10d";
    };

    distributedBuilds = true;

    buildMachines = [
      {
        hostName = "loki";
        system = "x86_64-linux";
        sshUser = config.hostSpec.username;
        sshKey = config.hostSpec.home + "/.ssh/id_ed25519";
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    nh
  ];
}
