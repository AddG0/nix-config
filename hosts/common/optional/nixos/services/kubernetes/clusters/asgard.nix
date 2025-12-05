# Asgard k3s cluster configuration
# Docs: https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/k3s/README.md
{
  config,
  lib,
  pkgs,
  nix-secrets,
  ...
}: let
  inherit (config.hostSpec.networking) hostsAddr;
  inherit (hostsAddr.asgard) ipv4 iface;

  cluster = {
    vip = ipv4;
    masterAddr = "https://${ipv4}:6443";
    nodes = {
      odin = "server";
      loki = "agent";
      thor = "agent";
    };
  };

  currentNode = config.hostSpec.hostName;
  nodeRole = cluster.nodes.${currentNode};
  isServer = nodeRole == "server";
  isAgent = nodeRole == "agent";
in {
  # ==========================================================================
  # Firewall - open k3s ports
  # ==========================================================================
  networking.firewall = {
    allowedTCPPorts = lib.optionals isServer [6443]; # k3s API server
    allowedUDPPorts = [8472]; # flannel VXLAN
  };

  # ==========================================================================
  # Secrets
  # ==========================================================================
  sops.secrets.k3sMainToken = {
    sopsFile = "${nix-secrets}/services/kubernetes/asgard.yaml";
    key = "token";
  };

  # ==========================================================================
  # k3s configuration
  # ==========================================================================
  services.k3s = {
    enable = true;
    role = nodeRole;
    serverAddr = lib.mkIf isAgent cluster.masterAddr;
    tokenFile = config.sops.secrets.k3sMainToken.path;

    addons.kube-vip = lib.mkIf isServer {
      enable = true;
      vipAddress = cluster.vip;
      interface = iface;
    };

    extraFlags = toString (lib.optionals isServer [
      "--tls-san=${cluster.vip}"
      "--disable=traefik"
      "--disable=servicelb"
      "--disable=metrics-server"
      "--disable=local-storage"
      "--disable-network-policy"
      "--disable-helm-controller"
      "--etcd-expose-metrics=true"
    ]);
  };

  # ==========================================================================
  # Longhorn dependencies
  # ==========================================================================
  environment.systemPackages = [pkgs.nfs-utils];
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };
}
