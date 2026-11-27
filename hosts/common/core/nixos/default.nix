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

  # Just above mkDefault (1000): outranks the installer ISO's default, yields to a host's plain assignment.
  system.stateVersion = lib.mkOverride 900 "26.05";

  powerManagement.cpuFreqGovernor = lib.mkIf (config.hostSpec.hostType == "desktop") "performance";

  # nm-online gates network-online -> multi-user -> graphical.target, and uwsm
  # waits on graphical.target: a workstation would block on DHCP before login.
  systemd.services.NetworkManager-wait-online.enable =
    lib.mkIf (config.hostSpec.hostType != "server") false;

  services.displayManager.autoLogin = {
    # nixpkgs enables autologin whenever a user is set, so the default user can't imply it.
    enable = lib.mkDefault false;
    user = lib.mkDefault config.hostSpec.primaryDesktopUsername;
  };

  documentation.nixos.enable = false;
}
