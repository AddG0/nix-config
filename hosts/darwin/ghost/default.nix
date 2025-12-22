#############################################################
#
#  ghost - Main Desktop
#  MacOS running on M4 Max, 128GB RAM
#
###############################################################
{lib, ...}: {
  imports = lib.flatten [
    ./databases.nix
    ./monitoring.nix

    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        # "darwin/vban-walkie.nix"
        "darwin/services/tailscale.nix" # mesh VPN for secure remote access

        #################### Optional Applications ####################
        # "darwin/applications/autodesk-fusion.nix"
        "darwin/applications/browsers.nix"
        "darwin/applications/deskflow.nix"
        "darwin/applications/docker.nix"
        "darwin/applications/gitkraken.nix"
        "darwin/applications/hovrly.nix"
        "darwin/applications/jprofiler.nix"
        "darwin/applications/lens.nix"
        "darwin/applications/motion.nix"
        "darwin/applications/notchnook.nix"
        "darwin/applications/notion-calendar.nix"
        # "darwin/applications/obsidian.nix"
        # "darwin/applications/ollama.nix"
        "darwin/applications/synology.nix"
        # "darwin/applications/tencent-lemon.nix"
        "darwin/applications/claude.nix"
        "darwin/applications/vpn.nix"
        "darwin/applications/ghostty.nix"
        "darwin/applications/bleunlock.nix"
        "darwin/applications/wifiman.nix"
        "darwin/applications/1password.nix"

        #################### Desktop ####################
      ])
    ))
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
