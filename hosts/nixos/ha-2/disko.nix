# The disk `just bootstrap` wiped for this host, and its nixos-facter hardware report.
{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToHosts "common/disks/btrfs.nix")
  ];

  _module.args.disk = "/dev/disk/by-id/nvme-FORESEE_XP1000F512G_NBQ362Q000060";

  hardware.facter.reportPath = ./facter.json;
}
