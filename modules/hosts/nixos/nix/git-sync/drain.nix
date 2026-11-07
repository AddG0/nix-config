# Drains the host's Kubernetes node before a reboot git-sync starts, and uncordons it once the host is back.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nix.git-sync;
  inherit (cfg.drainKubernetesNode) kubectl;
  node = config.networking.hostName;
  stateDirectory = "nix-remote-rebuild";

  nodeScript = pkgs.writeShellApplication {
    name = "nix-remote-rebuild-node";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      # Only a cordon git-sync made is undone after the boot, so a node a person cordoned stays cordoned.
      marker="$STATE_DIRECTORY/cordoned-node"
      drain_seconds=''${DRAIN_SECONDS:-300}
      retry_seconds=''${UNCORDON_RETRY_SECONDS:-10}

      # Never fails: the reboot it comes before applies a new kernel, so a drain that fails or hangs is logged and skipped.
      drain() {
        if ! unschedulable=$(timeout 30 ${kubectl} get node ${node} -o jsonpath='{.spec.unschedulable}'); then
          echo "Cannot read Kubernetes node ${node}; rebooting without draining it." >&2
          return 0
        fi
        if [ "$unschedulable" = true ]; then
          echo "Kubernetes node ${node} was already cordoned; it stays cordoned after the reboot."
        else
          echo ${node} >"$marker"
        fi
        echo "Draining Kubernetes node ${node} before the reboot, for at most ''${drain_seconds}s..."
        # A PodDisruptionBudget can hold an eviction forever, and kubectl's own --timeout misses an API server that stops answering.
        if timeout --kill-after=10 "$drain_seconds" ${kubectl} drain ${node} --ignore-daemonsets --delete-emptydir-data --force; then
          echo "Drained ${node}."
        else
          echo "Draining ${node} failed or timed out (exit $?); rebooting anyway." >&2
        fi
      }

      # The API server can take minutes to answer after a boot while etcd catches up.
      uncordon() {
        if [ ! -f "$marker" ]; then
          echo "git-sync cordoned no node before this boot; nothing to uncordon."
          return 0
        fi
        for _ in $(seq 90); do
          if timeout 30 ${kubectl} uncordon ${node}; then
            rm -f "$marker"
            return 0
          fi
          sleep "$retry_seconds"
        done
        echo "Could not uncordon Kubernetes node ${node}; it stays cordoned until 'systemctl start nix-remote-rebuild-uncordon' succeeds." >&2
        return 1
      }

      case "''${1:-}" in
        drain) drain ;;
        uncordon) uncordon ;;
        *)
          echo "Usage: nix-remote-rebuild-node drain|uncordon" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  options.nix.git-sync.drainKubernetesNode = {
    enable = lib.mkEnableOption ''
      cordoning and draining the host's Kubernetes node, named for its hostname, before a reboot
      git-sync starts, and uncordoning it once the host is back. A drain that fails or outlasts
      5 minutes is logged and the reboot goes ahead'';

    kubectl = lib.mkOption {
      type = lib.types.str;
      description = "The kubectl command, run as root with credentials the node already holds that may cordon it and evict its pods.";
      example = lib.literalExpression ''"''${config.services.k3s.package}/bin/k3s kubectl"'';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.drainKubernetesNode.enable) {
    nix.git-sync.preRebootHook = "${nodeScript}/bin/nix-remote-rebuild-node drain";

    systemd.services.nix-remote-rebuild-uncordon = {
      description = "Uncordon the Kubernetes node git-sync drained before its reboot";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        # Not oneshot: multi-user.target must not wait the minutes the API server can take to answer.
        Type = "exec";
        StateDirectory = stateDirectory;
        ExecStart = "${nodeScript}/bin/nix-remote-rebuild-node uncordon";
      };
    };
  };
}
