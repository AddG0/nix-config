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

  powerManagement.cpuFreqGovernor = lib.mkIf (config.hostSpec.hostType == "desktop") "performance";

  # nm-online gates network-online -> multi-user -> graphical.target, and uwsm
  # waits on graphical.target: a workstation would block on DHCP before login.
  systemd.services.NetworkManager-wait-online.enable =
    lib.mkIf (config.hostSpec.hostType != "server") false;

  documentation.nixos.enable = false;
}
