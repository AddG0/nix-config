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

  agentIPs = lib.pipe cluster.nodes [
    builtins.attrNames
    (builtins.filter (n: cluster.nodes.${n} == "agent"))
    (map (n: hostsAddr.${n}.ipv4))
  ];
in {
  # ==========================================================================
  # Firewall - restrict API server access to cluster nodes only
  # ==========================================================================
  networking.firewall = lib.mkIf isServer {
    extraCommands = ''
      iptables -I INPUT -p tcp --dport 6443 -s 127.0.0.1 -j ACCEPT
      iptables -I INPUT -p tcp --dport 6443 -s ${cluster.vip} -j ACCEPT
      ${lib.concatMapStringsSep "\n" (ip: "iptables -I INPUT -p tcp --dport 6443 -s ${ip} -j ACCEPT") agentIPs}
      iptables -A INPUT -p tcp --dport 6443 -j DROP
    '';
    extraStopCommands = ''
      iptables -D INPUT -p tcp --dport 6443 -s 127.0.0.1 -j ACCEPT || true
      iptables -D INPUT -p tcp --dport 6443 -s ${cluster.vip} -j ACCEPT || true
      ${lib.concatMapStringsSep "\n" (ip: "iptables -D INPUT -p tcp --dport 6443 -s ${ip} -j ACCEPT || true") agentIPs}
      iptables -D INPUT -p tcp --dport 6443 -j DROP || true
    '';
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
