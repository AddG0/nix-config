#############################################################
#
#  ghost - Main Desktop
#  MacOS running on M4 Max, 128GB RAM
#
###############################################################
{lib, ...}: {
  imports = lib.flatten [
    (with lib.custom.optional.hosts.darwin.services; [
      server-mode # headless: no sleep, SSH, auto-restart
      tailscale # mesh VPN for secure remote access
    ])
  ];

  time.timeZone = "America/Chicago";

  hostSpec = {
    hostName = "ghost";
    hostPlatform = "aarch64-darwin";
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = 5;
}
