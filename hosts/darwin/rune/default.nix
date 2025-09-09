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

      #################### Optional Applications ####################
      "common/optional/darwin/applications/1password.nix"
      "common/optional/darwin/applications/browsers.nix"
      "common/optional/darwin/applications/docker.nix"
      "common/optional/darwin/applications/lens.nix"
      "common/optional/darwin/applications/notchnook.nix"
      "common/optional/darwin/applications/notion-calendar.nix"
      # "common/optional/darwin/applications/ollama.nix"
      # "common/optional/darwin/applications/tencent-lemon.nix"
      "common/optional/darwin/applications/claude.nix"
      "common/optional/darwin/applications/vpn.nix"
      "common/optional/darwin/applications/ghostty.nix"

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
