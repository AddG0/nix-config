# https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/k3s/README.md
{
  config,
  pkgs,
  ...
}: let 
  nodes = {
    odin = {
      role = "server";
    };
    odin = {
      role = "server";
    };
    odin = {
      role = "server";
    };
  };
in {
  networking.firewall.allowedTCPPorts = [
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
    # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
    # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  ];
  networking.firewall.allowedUDPPorts = [
    # 8472 # k3s, flannel: required if using multi-node for inter-node networking
  ];

  sops.secrets = {
    k3sMainToken = {
      sopsFile = "${nix-secrets}/services/kubernetes/production.yaml";
      key = "token";
    };
  };

  services.k3s = {
    enable = true;
    tokenFIle = config.sops.k3sMainToken.path;
    role = nodes.${config.hostSpec.hostname}.role;
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
