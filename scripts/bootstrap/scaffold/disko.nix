# The disk `just bootstrap` wiped for this host, and its nixos-facter hardware report.
{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToHosts "common/disks/luks-btrfs.nix")
  ];

  _module.args.disk = "@DISK@";

  hardware.facter.reportPath = ./facter.json;
}
