# Lets clients offload builds here: a locked-down, key-only `builder` user trusted by the nix daemon.
{
  config,
  pkgs,
  ...
}: let
  inherit (import ../../_nix-builders.nix) builders publicKey;
  host = config.hostSpec.hostName;
in {
  assertions = [
    {
      assertion = builders ? ${host};
      message = "nix-builders: ${host} imports nix-builders.builder but has no entry in hosts/common/optional/_nix-builders.nix, so no client will use it";
    }
  ];

  users.users.builder = {
    isSystemUser = true;
    group = "builder";
    description = "Nix remote builder";

    shell = pkgs.bashInteractive;

    home = "/var/lib/builder";
    createHome = true;

    openssh.authorizedKeys.keys = [publicKey];
  };

  users.groups.builder = {};

  nix.settings.trusted-users = ["builder"];
}
