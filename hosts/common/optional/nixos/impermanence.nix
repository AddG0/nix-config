# System state kept across the root wipe; pair with common/disks/luks-btrfs-impermanence.nix.
{
  inputs,
  config,
  lib,
  ...
}: let
  # Read in place: activation runs in initrd and writes /etc/ssh, which a persisted /etc/ssh would then cover.
  hostKey = "${config.hostSpec.persistFolder}/etc/ssh/ssh_host_ed25519_key";
in {
  imports = [inputs.impermanence.nixosModules.impermanence];

  environment.persistence.${config.hostSpec.persistFolder} = {
    hideMounts = true;
    directories = [
      "/var/lib/logrotate"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/log"
    ];
    files = ["/etc/machine-id"];
  };

  services = {
    openssh.hostKeys = lib.mkForce [
      {
        path = hostKey;
        type = "ed25519";
      }
    ];
    # Its default state file sits on the wiped root, a single file it replaces by rename.
    logrotate.extraArgs = ["--state" "/var/lib/logrotate/status"];
  };

  sops.age.sshKeyPaths = lib.mkForce [hostKey];
}
