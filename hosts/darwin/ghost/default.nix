#############################################################
#
#  ghost - Main Desktop
#  MacOS running on M4 Max, 128GB RAM
#
###############################################################
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (map lib.custom.relativeToHosts [
      #################### Required Configs ####################
      "common/core"

      #################### Host-specific Optional Configs ####################
      "common/optional/darwin/ghostty"
      "common/optional/darwin/vban-walkie.nix"

      #################### Desktop ####################
    ])
  ];

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
