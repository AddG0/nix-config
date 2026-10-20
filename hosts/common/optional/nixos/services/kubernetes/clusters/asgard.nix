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

  nodeSources = lib.mapAttrsToList (node: _role: "${hostsAddr.${node}.ipv4}/32") cluster.nodes;

  # Same-node traffic arrives from the pod CIDR; cross-node traffic is masqueraded
  # to the sending node's address.
  clusterSources = [podCidr] ++ nodeSources;

  allow = proto: port: map (src: "nixos-fw -p ${proto} --dport ${toString port} -s ${src} -j nixos-fw-accept");

  firewallRules = lib.flatten (
    [
      (map (port: allow "tcp" port clusterSources) [10250 9100]) # kubelet, node-exporter
      (allow "udp" 51820 nodeSources) # flannel WireGuard
      (map (proto: allow proto 7946 nodeSources) ["tcp" "udp"]) # MetalLB memberlist
    ]
    ++ lib.optionals isServer [
      (allow "tcp" 6443 clusterSources)
      # Clients outside the cluster reach the API only through the VIP.
      "nixos-fw -p tcp --dport 6443 -d ${cluster.vip}/32 -j nixos-fw-accept"
      (map (port: allow "tcp" port nodeSources) [2379 2380]) # etcd client, peer
    ]
  );

  cluster = {
    vip = ipv4;
    masterAddr = "https://${ipv4}:6443";
    nodes = {
      odin = "server";
      loki = "server";
      thor = "server";
      kvasir = "agent";
    };
  };

  currentNode = config.hostSpec.hostName;
  nodeRole = cluster.nodes.${currentNode};
  isServer = nodeRole == "server";
in {
  # ==========================================================================
  # Firewall - k3s ports, open to cluster sources only
  # ==========================================================================
  networking.firewall = {
    extraCommands = lib.concatMapStringsSep "\n" (rule: "iptables -A ${rule}") firewallRules;
    extraStopCommands = lib.concatMapStringsSep "\n" (rule: "iptables -D ${rule} || true") firewallRules;
  };

  # ==========================================================================
  # Secrets
  # ==========================================================================
  # The server token is cluster-admin and decrypts the etcd bootstrap data, so agents never hold it.
  sops.secrets = {
    k3sServerToken = lib.mkIf isServer {
      sopsFile = "${nix-secrets}/services/kubernetes/asgard-server.yaml";
      key = "token";
    };
    # Full K10<ca-hash> form: agents pin the cluster CA instead of trusting whatever answers.
    k3sAgentToken = {
      sopsFile = "${nix-secrets}/services/kubernetes/asgard-agent.yaml";
      key = "token";
    };
  };

  # ==========================================================================
  # k3s configuration
  # ==========================================================================
  services.k3s = {
    enable = true;
    role = nodeRole;
    # Every node joins via the VIP, so a wiped server rejoins instead of founding a new cluster.
    serverAddr = cluster.masterAddr;
    tokenFile =
      if isServer
      then config.sops.secrets.k3sServerToken.path
      else config.sops.secrets.k3sAgentToken.path;
    agentTokenFile = lib.mkIf isServer config.sops.secrets.k3sAgentToken.path;

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
        # kube-proxy DNATs NodePorts before nixos-fw sees them; MetalLB IPs have their own rules.
        "--kube-proxy-arg=nodeport-addresses=127.0.0.0/8"
      ]
      ++ lib.optionals isServer [
        "--tls-san=${cluster.vip}"
        # Agents read the backend from the server; every server must carry the same value.
        "--flannel-backend=wireguard-native"
        # Run `k3s secrets-encrypt enable` before first deploying this, or each server generates its own key.
        "--secrets-encryption"
        "--disable=traefik"
        "--disable=servicelb"
        "--disable=metrics-server"
        "--disable=local-storage"
        "--disable-network-policy"
        "--disable-helm-controller"
        "--etcd-expose-metrics=true"
      ]);
  };

  # The module ships TimeoutStartSec=0, so a wedged start never fails and
  # Restart=always never fires. Minutes, not seconds: etcd catch-up is slow.
  systemd.services.k3s.serviceConfig.TimeoutStartSec = lib.mkForce "15m";

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
