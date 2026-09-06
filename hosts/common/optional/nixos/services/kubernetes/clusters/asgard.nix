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

  # Each node gets a /24 of this.
  podCidr = "10.42.0.0/16";

  scrapePorts = [10250 9100];

  # Same-node scrapes arrive from the pod CIDR; cross-node ones are masqueraded
  # to the sending node's address.
  scrapeSources = [podCidr] ++ lib.mapAttrsToList (node: _role: "${hostsAddr.${node}.ipv4}/32") cluster.nodes;

  scrapeRules = lib.concatMap (port:
    map (src: "nixos-fw -p tcp --dport ${toString port} -s ${src} -j nixos-fw-accept") scrapeSources)
  scrapePorts;

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

    # Kubelet (10250) and node-exporter (9100, hostNetwork). Scraped from inside
    # the cluster only, never opened to the LAN.
    extraCommands = lib.concatMapStringsSep "\n" (rule: "iptables -A ${rule}") scrapeRules;
    extraStopCommands = lib.concatMapStringsSep "\n" (rule: "iptables -D ${rule} || true") scrapeRules;
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
    # Only ever one node: a second bootstraps its own cluster, and so does moving it.
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

    extraFlags = toString ([
        # Pinned: k3s otherwise autodetects the kube-vip VIP off the shared NIC,
        # so a server rebooting while it holds the VIP advertises 10.61.60.2 for
        # etcd peering and never rejoins -- "not a member of the etcd cluster".
        "--node-ip=${hostsAddr.${currentNode}.ipv4}"
      ]
      ++ lib.optionals isServer [
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
