# Midgard Nomad cluster — client config for all nodes
# Provides: firewall, gossip encryption, ACLs, base Nomad client
{
  config,
  lib,
  pkgs,
  nix-secrets,
  ...
}: let
  inherit (config.hostSpec) username;
  inherit (config.hostSpec.networking) hostsAddr;
in {
  # ==========================================================================
  # Firewall — Nomad ports
  # ==========================================================================
  networking.firewall = {
    allowedTCPPorts = [
      4646 # HTTP API
      4647 # RPC
      4648 # Serf
    ];
    allowedUDPPorts = [
      4648 # Serf
    ];
  };

  # ==========================================================================
  # Secrets
  # ==========================================================================
  sops.secrets.nomadEncryptKey = {
    sopsFile = "${nix-secrets}/services/nomad/cluster.yaml";
    key = "encrypt_key";
  };

  sops.templates."nomad-gossip.json" = {
    content = builtins.toJSON {
      server = {
        encrypt = config.sops.placeholder.nomadEncryptKey;
      };
    };
  };

  # ==========================================================================
  # Nomad
  # ==========================================================================
  services.nomad = {
    enable = true;
    dropPrivileges = false; # required for exec driver and Docker
    enableDocker = true;

    extraPackages = [pkgs.cni-plugins];

    extraSettingsPaths = [
      config.sops.templates."nomad-gossip.json".path
    ];

    settings = {
      datacenter = "midgard";
      region = "home";
      bind_addr = "0.0.0.0";

      acl = {
        enabled = true;
      };

      client = {
        enabled = true;
        servers = [hostsAddr.odin.ipv4];
        cni_path = "${pkgs.cni-plugins}/bin";
        node_class = "server";
      };

      plugin = [
        {
          raw_exec = [
            {
              config = [
                {
                  enabled = true;
                }
              ];
            }
          ];
        }
        {
          docker = [
            {
              config = [
                {
                  allow_privileged = false;
                  volumes = {enabled = true;};
                }
              ];
            }
          ];
        }
      ];
    };
  };
}
