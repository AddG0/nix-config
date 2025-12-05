# kube-vip DaemonSet for k3s control plane HA
# https://kube-vip.io/docs/usage/k3s/
# https://kube-vip.io/docs/installation/daemonset/
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.k3s.addons.kube-vip;
in {
  options.services.k3s.addons.kube-vip = {
    enable = mkEnableOption "kube-vip for k3s control plane HA";

    vipAddress = mkOption {
      type = types.str;
      description = "Virtual IP address for the control plane";
      example = "192.168.50.10";
    };

    interface = mkOption {
      type = types.str;
      default = "eth0";
      description = "Network interface to bind the VIP to";
    };

    version = mkOption {
      type = types.str;
      default = "0.8.7";
      description = "kube-vip image version";
    };

    enableServices = mkOption {
      type = types.bool;
      default = false;
      description = "Enable kube-vip for LoadBalancer services. Disable if using MetalLB.";
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      kube-vip-rbac.source = builtins.fetchurl {
        url = "https://kube-vip.io/manifests/rbac.yaml";
        sha256 = "0hn6dyn6g742ihakkp7k3bnjgmfzx965kizmwb6axbx2csplkbb8";
      };

      kube-vip-ds.content = {
        apiVersion = "apps/v1";
        kind = "DaemonSet";
        metadata = {
          name = "kube-vip-ds";
          namespace = "kube-system";
          labels = {
            "app.kubernetes.io/name" = "kube-vip-ds";
            "app.kubernetes.io/version" = cfg.version;
          };
        };
        spec = {
          selector.matchLabels."app.kubernetes.io/name" = "kube-vip-ds";
          template = {
            metadata.labels."app.kubernetes.io/name" = "kube-vip-ds";
            spec = {
              affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms = [
                {
                  matchExpressions = [
                    {
                      key = "node-role.kubernetes.io/master";
                      operator = "Exists";
                    }
                  ];
                }
                {
                  matchExpressions = [
                    {
                      key = "node-role.kubernetes.io/control-plane";
                      operator = "Exists";
                    }
                  ];
                }
              ];
              containers = [
                {
                  name = "kube-vip";
                  image = "ghcr.io/kube-vip/kube-vip:v${cfg.version}";
                  imagePullPolicy = "IfNotPresent";
                  args = ["manager"];
                  env = [
                    {
                      name = "vip_arp";
                      value = "true";
                    }
                    {
                      name = "port";
                      value = "6443";
                    }
                    {
                      name = "vip_interface";
                      value = cfg.interface;
                    }
                    {
                      name = "vip_cidr";
                      value = "32";
                    }
                    {
                      name = "cp_enable";
                      value = "true";
                    }
                    {
                      name = "cp_namespace";
                      value = "kube-system";
                    }
                    {
                      name = "vip_ddns";
                      value = "false";
                    }
                    {
                      name = "svc_enable";
                      value = boolToString cfg.enableServices;
                    }
                    {
                      name = "svc_leasename";
                      value = "plndr-svcs-lock";
                    }
                    {
                      name = "vip_leaderelection";
                      value = "true";
                    }
                    {
                      name = "vip_leasename";
                      value = "plndr-cp-lock";
                    }
                    {
                      name = "vip_leaseduration";
                      value = "5";
                    }
                    {
                      name = "vip_renewdeadline";
                      value = "3";
                    }
                    {
                      name = "vip_retryperiod";
                      value = "1";
                    }
                    {
                      name = "address";
                      value = cfg.vipAddress;
                    }
                    {
                      name = "prometheus_server";
                      value = ":2112";
                    }
                  ];
                  resources = {};
                  securityContext.capabilities.add = ["NET_ADMIN" "NET_RAW"];
                }
              ];
              hostNetwork = true;
              serviceAccountName = "kube-vip";
              tolerations = [
                {
                  effect = "NoSchedule";
                  operator = "Exists";
                }
                {
                  effect = "NoExecute";
                  operator = "Exists";
                }
              ];
            };
          };
        };
      };
    };
  };
}
