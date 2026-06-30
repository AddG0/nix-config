#############################################################
#
#  ghost - Main Desktop
#  MacOS running on M4 Max, 128GB RAM
#
###############################################################
{lib, ...}: {
  imports = lib.flatten [
    (map lib.custom.relativeToHosts (map (f: "common/optional/${f}") [
      "darwin/services/tailscale.nix" # mesh VPN for secure remote access
      "darwin/services/server-mode.nix" # headless: no sleep, SSH, auto-restart
    ]))
  ];

  nix.remoteBuilder.enableClient = true;

  time.timeZone = "America/Chicago";

  hostSpec = {
    hostName = "ghost";
    hostPlatform = "aarch64-darwin";
  };

  security.firewall = {
    enable = false;
    allowedTCPPorts = [
      22
    ];
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = 5;
}
