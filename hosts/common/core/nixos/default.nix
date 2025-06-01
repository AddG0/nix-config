{
  inputs,
  outputs,
  config,
  lib,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
    inputs.nixvirt.nixosModules.default
    ../../users/root
  ];

  networking.hostName = config.hostSpec.hostName;
}
