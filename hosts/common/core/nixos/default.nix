{
  inputs,
  self,
  config,
  lib,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
    self.nixosModules.default
    inputs.nixvirt.nixosModules.default
    ../../users/root
  ];

  networking.hostName = config.hostSpec.hostName;

  system.stateVersion = config.hostSpec.system.stateVersion;
}
