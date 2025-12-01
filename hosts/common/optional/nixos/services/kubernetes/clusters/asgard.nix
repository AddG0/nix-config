# https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/k3s/README.md
{
  config,
  lib,
  pkgs,
  nix-secrets,
  ...
}: let
  inherit (config.hostSpec.networking) hostsAddr;
  masterAddr = "https://${hostsAddr.odin.ipv4}:6443";
  currentNode = config.hostSpec.hostName;
  nodes = {
    odin = "server";
    loki = "agent";
    thor = "agent";
  };
  isServer = nodes.${currentNode} == "server";
  isAgent = nodes.${currentNode} == "agent";
  agentIPs = builtins.map (n: hostsAddr.${n}.ipv4) (builtins.filter (n: nodes.${n} == "agent") (builtins.attrNames nodes));
in {
  # Only allow API server access from agent nodes (on server only)
  networking.firewall.extraCommands = lib.mkIf isServer (builtins.concatStringsSep "\n" (
    builtins.map (ip: "iptables -A INPUT -p tcp --dport 6443 -s ${ip} -j ACCEPT") agentIPs
    ++ ["iptables -A INPUT -p tcp --dport 6443 -j DROP"]
  ));
  networking.firewall.allowedUDPPorts = [
    # 8472 # k3s, flannel: required if using multi-node for inter-node networking
  ];

  sops.secrets = {
    k3sMainToken = {
      sopsFile = "${nix-secrets}/services/kubernetes/asgard.yaml";
      key = "token";
    };
  };

  services.k3s = {
    enable = true;
    role = nodes.${currentNode};
    serverAddr = if isAgent then masterAddr else "";
    tokenFile = config.sops.secrets.k3sMainToken.path;
    extraFlags = toString [
      "--disable=traefik"
      "--disable=servicelb" # we use kube-vip instead
      "--disable-network-policy"
      "--disable=metrics-server"
      "--disable=local-storage"
      "--disable-helm-controller" # we use argocd instead
      "--etcd-expose-metrics=true"
    ];
  };

  # Below is required for longhorn
  environment.systemPackages = [pkgs.nfs-utils];
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };
}
