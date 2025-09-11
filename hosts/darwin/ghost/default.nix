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
    ./databases.nix
    ./monitoring.nix

    (map lib.custom.relativeToHosts [
      #################### Required Configs ####################
      "common/core"

      #################### Host-specific Optional Configs ####################
      "common/optional/darwin/vban-walkie.nix"

      #################### Optional Applications ####################
      "common/optional/darwin/applications/1password.nix"
      "common/optional/darwin/applications/autodesk-fusion.nix"
      "common/optional/darwin/applications/bartender.nix"
      "common/optional/darwin/applications/browsers.nix"
      "common/optional/darwin/applications/deskflow.nix"
      "common/optional/darwin/applications/docker.nix"
      "common/optional/darwin/applications/gitkraken.nix"
      "common/optional/darwin/applications/hovrly.nix"
      "common/optional/darwin/applications/jprofiler.nix"
      "common/optional/darwin/applications/lens.nix"
      "common/optional/darwin/applications/motion.nix"
      "common/optional/darwin/applications/notchnook.nix"
      "common/optional/darwin/applications/notion-calendar.nix"
      "common/optional/darwin/applications/obsidian.nix"
      # "common/optional/darwin/applications/ollama.nix"
      "common/optional/darwin/applications/synology.nix"
      # "common/optional/darwin/applications/tencent-lemon.nix"
      "common/optional/darwin/applications/claude.nix"
      "common/optional/darwin/applications/vpn.nix"
      "common/optional/darwin/applications/ghostty.nix"
      "common/optional/darwin/applications/bleunlock.nix"
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
