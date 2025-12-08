# Nix Remote Builder User (NixOS)
#
# Creates a minimal, locked-down user for remote Nix builds when enabled.
# This user can only be accessed via SSH key and can only run Nix commands.
#
# To enable this host as a builder, set in your host config:
#   nix.remoteBuilder.enable = true;
#   nix.remoteBuilder.publicKey = "ssh-ed25519 AAAA...";
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nix.remoteBuilder;
in {
  config = mkIf cfg.enable {
    users.users.builder = {
      isSystemUser = true;
      group = "builder";
      description = "Nix remote builder";

      shell = pkgs.bashInteractive;

      home = "/var/lib/builder";
      createHome = true;

      openssh.authorizedKeys.keys = mkIf (cfg.publicKey != "") [cfg.publicKey];
    };

    users.groups.builder = {};

    # Allow builder user to use Nix
    nix.settings.trusted-users = ["builder"];
  };
}
