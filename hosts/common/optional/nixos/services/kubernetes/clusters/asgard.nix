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
  inherit (hostsAddr.asgard) ipv4;

  cluster = {
    vip = ipv4;
    masterAddr = "https://${ipv4}:6443";
    nodes = {
      odin = "server";
      loki = "server";
      thor = "server";
    };
    initNode = "odin";
  };

  currentNode = config.hostSpec.hostName;
  nodeRole = cluster.nodes.${currentNode};
  isServer = nodeRole == "server";
  isInitNode = currentNode == cluster.initNode;
in {
  # ==========================================================================
  # Firewall - open k3s ports
  # ==========================================================================
  networking.firewall = {
    allowedTCPPorts =
      lib.optionals isServer [
        6443 # k3s API server
        2379 # etcd client
        2380 # etcd peer
      ]
      ++ [7946]; # MetalLB memberlist
    allowedUDPPorts = [8472 7946]; # flannel VXLAN, MetalLB memberlist
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
    # Only ever one node: a second bootstraps its own cluster instead of joining, and
    # moving it to a different node would do the same.
    clusterInit = isInitNode;
    serverAddr = lib.mkIf (!isInitNode) cluster.masterAddr;
    tokenFile = config.sops.secrets.k3sMainToken.path;

    addons.kube-vip = lib.mkIf isServer {
      enable = true;
      vipAddress = cluster.vip;
      # NICs differ per host (enp131s0 / enp2s0 / enp87s0) but a DaemonSet carries one
      # config for all of them -- kube-vip#273. Empty autodetects from the default route.
      interface = "";
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

  # flannel takes the first address on its interface after sorting with IFA_F_PERMANENT
  # preferred (compareAddrs, flannel pkg/ip/iface.go), so kube-vip's permanent VIP beats
  # a DHCP lease. A reservation does not help -- the lease is still flagged dynamic.
  assertions = [
    {
      assertion = !config.networking.useDHCP && config.networking.interfaces != {};
      message = "asgard: ${currentNode} needs a statically assigned address (import nixos/static-networking.nix), or flannel binds its VXLAN tunnel to the kube-vip VIP";
    }
  ];

  # ==========================================================================
  # Longhorn dependencies
  # ==========================================================================
  environment.systemPackages = [pkgs.nfs-utils];
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };

  # Longhorn nsenters into the host mount namespace and resolves `iscsiadm`/`mount`
  # against a hardcoded FHS PATH that NixOS has none of; without this, volumes hang
  # in `attaching` forever. https://github.com/longhorn/longhorn/issues/2166
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];
}
