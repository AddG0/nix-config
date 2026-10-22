# CoreDNS from the upstream Helm chart, rendered at build time, in place of k3s's bundled addon.
# https://docs.k3s.io/installation/packaged-components
{customPkgs, ...}: {
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.k3s.addons.coredns;

  release = "coredns-helm";

  values = {
    k8sAppLabelOverride = "kube-dns";
    replicaCount = 3;
    priorityClassName = "system-cluster-critical";
    resources = {
      requests = {
        cpu = "100m";
        memory = "70Mi";
      };
      limits = {
        cpu = null;
        memory = "170Mi";
      };
    };
    nodeSelector."kubernetes.io/os" = "linux";
    tolerations = [
      {
        key = "CriticalAddonsOnly";
        operator = "Exists";
      }
      {
        key = "node-role.kubernetes.io/control-plane";
        operator = "Exists";
        effect = "NoSchedule";
      }
    ];
    topologySpreadConstraints = [
      {
        maxSkew = 1;
        topologyKey = "kubernetes.io/hostname";
        whenUnsatisfiable = "DoNotSchedule";
        # Otherwise a NotReady or tainted node counts as an empty domain and strands a replica.
        nodeTaintsPolicy = "Honor";
        labelSelector.matchLabels = {
          "app.kubernetes.io/instance" = release;
          "app.kubernetes.io/name" = "coredns";
        };
      }
    ];
    podDisruptionBudget.maxUnavailable = 1;
    livenessProbe = {
      initialDelaySeconds = 60;
      periodSeconds = 10;
      timeoutSeconds = 1;
      failureThreshold = 3;
    };
    readinessProbe = {
      initialDelaySeconds = 0;
      periodSeconds = 2;
      timeoutSeconds = 1;
      failureThreshold = 3;
    };
    zoneFiles = [
      {
        filename = "NodeHosts";
        contents = concatStrings (mapAttrsToList (host: ip: "${ip} ${host}\n") cfg.nodeHosts);
      }
    ];
    servers = [
      {
        zones = [
          {
            zone = ".";
            use_tcp = true;
          }
        ];
        port = 53;
        plugins = [
          {name = "errors";}
          {
            name = "health";
            configBlock = "lameduck 10s";
          }
          {name = "ready";}
          {
            name = "kubernetes";
            parameters = "cluster.local in-addr.arpa ip6.arpa";
            configBlock = "pods insecure\nfallthrough in-addr.arpa ip6.arpa";
          }
          {
            name = "hosts";
            parameters = "/etc/coredns/NodeHosts";
            configBlock = "ttl 60\nreload 15s\nfallthrough";
          }
          {
            name = "prometheus";
            parameters = ":9153";
          }
          {
            name = "cache";
            parameters = 30;
          }
          {name = "loop";}
          {name = "reload";}
          {name = "loadbalance";}
          {
            name = "forward";
            parameters = ". /etc/resolv.conf";
          }
        ];
      }
    ];
  };

  # k3s's own kube-dns, verbatim; once its addon is disabled, dropping this deletes cluster DNS.
  kubeDnsService = {
    apiVersion = "v1";
    kind = "Service";
    metadata = {
      name = "kube-dns";
      namespace = "kube-system";
      annotations = {
        "prometheus.io/port" = "9153";
        "prometheus.io/scrape" = "true";
      };
      labels = {
        k8s-app = "kube-dns";
        "kubernetes.io/cluster-service" = "true";
        "kubernetes.io/name" = "CoreDNS";
      };
    };
    spec = {
      selector.k8s-app = "kube-dns";
      inherit (cfg) clusterIP;
      clusterIPs = [cfg.clusterIP];
      ipFamilyPolicy = "SingleStack";
      ports = [
        {
          name = "dns";
          port = 53;
          protocol = "UDP";
        }
        {
          name = "dns-tcp";
          port = 53;
          protocol = "TCP";
        }
        {
          name = "metrics";
          port = 9153;
          protocol = "TCP";
        }
      ];
    };
  };

  # The chart's own Service can't carry k3s's port names, so ours replaces it.
  manifest =
    pkgs.runCommand "${release}.json" {
      nativeBuildInputs = [pkgs.kubernetes-helm pkgs.yq-go];
      values = builtins.toJSON values;
      service = builtins.toJSON kubeDnsService;
      passAsFile = ["values" "service"];
    } ''
      export HOME=$TMPDIR
      {
        helm template ${release} ${customPkgs.coredns-helm-chart} \
          --namespace kube-system --values "$valuesPath" \
          | yq 'select(.kind != "Service")'
        echo ---
        cat "$servicePath"
      } | yq eval-all -o json '[.] | {"apiVersion": "v1", "kind": "List", "items": .}' > $out

      # A chart bump must not add a Service or drop the label kube-dns selects on.
      yq -e '[.items[] | select(.kind == "Service")] | length == 1' $out
      yq -e '.items[] | select(.kind == "Deployment") | .spec.template.metadata.labels."k8s-app" == "kube-dns"' $out
    '';
in {
  options.services.k3s.addons.coredns = {
    enable = mkEnableOption "CoreDNS from the upstream Helm chart";

    nodeHosts = mkOption {
      type = types.attrsOf types.str;
      description = "Node name to IP, served the way k3s's NodeHosts is";
      example = {node1 = "192.168.50.11";};
    };

    clusterIP = mkOption {
      type = types.str;
      default = "10.43.0.10";
      description = "kube-dns Service IP; must equal k3s's --cluster-dns";
    };

    disableBundled = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Pass `--disable=coredns`, deleting k3s's CoreDNS. A cluster already running it must first move
        kube-dns to this addon: k3s cannot adopt a Service whose clusterIP is allocated, so the prune would take it.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests.${release}.source = manifest;

    services.k3s.extraFlags = mkIf cfg.disableBundled ["--disable=coredns"];
  };
}
