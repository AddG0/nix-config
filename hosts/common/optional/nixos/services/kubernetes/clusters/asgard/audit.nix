# kube-apiserver audit logging on the asgard servers.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Under /var/log because the alloy-logs DaemonSet already mounts it from every node.
  auditLogDir = "/var/log/kubernetes/audit";

  writeVerbs = ["create" "update" "patch" "delete" "deletecollection"];

  # Rules are first-match, after https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/.
  auditPolicy = pkgs.writeText "asgard-audit-policy.json" (builtins.toJSON {
    apiVersion = "audit.k8s.io/v1";
    kind = "Policy";
    omitStages = ["RequestReceived"];
    rules = [
      {
        level = "None";
        users = ["system:kube-proxy"];
        verbs = ["watch"];
        resources = [
          {
            group = "";
            resources = ["endpoints" "services"];
          }
          {
            group = "discovery.k8s.io";
            resources = ["endpointslices"];
          }
        ];
      }
      {
        level = "None";
        nonResourceURLs = ["/healthz*" "/livez*" "/readyz*" "/version" "/metrics" "/api*" "/openapi*"];
      }
      # Leader-election heartbeats and Events would outnumber everything else combined.
      {
        level = "None";
        resources = [
          {
            group = "coordination.k8s.io";
            resources = ["leases"];
          }
          {
            group = "";
            resources = ["events"];
          }
          {
            group = "events.k8s.io";
            resources = ["events"];
          }
        ];
      }
      # Fields in one rule AND together, so users and groups need separate rules.
      {
        level = "None";
        verbs = ["get" "list" "watch"];
        # k3s control-plane client certs, pkg/daemons/control/deps/deps.go and pkg/server/handlers/handlers.go.
        users = [
          "system:apiserver"
          "system:kube-controller-manager"
          "system:kube-scheduler"
          "system:k3s-supervisor"
          "system:k3s-controller"
          "k3s-cloud-controller-manager"
        ];
      }
      {
        level = "None";
        verbs = ["get" "list" "watch"];
        userGroups = ["system:nodes"];
      }
      # Bodies here carry secret values or bearer tokens; must precede every Request-level rule.
      {
        level = "Metadata";
        resources = [
          {
            group = "";
            resources = ["secrets" "configmaps"];
          }
          {
            group = "authentication.k8s.io";
            resources = ["tokenreviews"];
          }
        ];
      }
      {
        level = "None";
        verbs = ["get" "list" "watch"];
        userGroups = ["system:serviceaccounts"];
      }
      # Access reviews change nothing, and controllers' own permission checks were ~40% of all bytes.
      {
        level = "None";
        userGroups = ["system:serviceaccounts"];
        resources = [
          {
            group = "authorization.k8s.io";
            resources = ["selfsubjectaccessreviews" "subjectaccessreviews" "localsubjectaccessreviews" "selfsubjectrulesreviews"];
          }
        ];
      }
      {
        level = "RequestResponse";
        verbs = writeVerbs;
        resources = [{group = "rbac.authorization.k8s.io";}];
      }
      {
        level = "Request";
        verbs = writeVerbs;
        resources = [{group = "";}];
      }
      {level = "Metadata";}
    ];
  });
in
  lib.mkIf (config.services.k3s.role == "server") {
    services.k3s.extraFlags = [
      # Retention from the k3s hardening guide (CIS 1.2.22-1.2.25).
      "--kube-apiserver-arg=audit-policy-file=${auditPolicy}"
      "--kube-apiserver-arg=audit-log-path=${auditLogDir}/audit.log"
      "--kube-apiserver-arg=audit-log-maxage=30"
      "--kube-apiserver-arg=audit-log-maxbackup=10"
      "--kube-apiserver-arg=audit-log-maxsize=100"
    ];

    # The apiserver would create it 0755; audit events name every user and resource.
    systemd.tmpfiles.rules = ["d ${auditLogDir} 0700 root root -"];
  }
