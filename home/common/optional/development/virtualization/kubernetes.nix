{pkgs, ...}: {
  home.packages = with pkgs; [
    kubectl
    kustomize_4
    # kubectx
    # kubebuilder
    # kubevpn
    helmfile
    kubernetes-helm

    # istioctl
    # clusterctl # for kubernetes cluster-api
    # kubevirt # virtctl
    # fluxcd
    argocd
    # telepresence2 # Local development against remote Kubernetes cluster
    # mirrord # Debug Kubernetes applications locally
    # kubefwd

    minikube # local kubernetes
    kind
  ];

  home.shellAliases = {
    k = "kubectl";
  };
}
