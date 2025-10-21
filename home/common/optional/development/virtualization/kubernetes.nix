{pkgs, ...}: {
  home.packages = with pkgs; [
    kubectl
    kustomize_4
    # kubectx
    # kubebuilder
    # kubevpn
    helmfile
    # istioctl
    # clusterctl # for kubernetes cluster-api
    # kubevirt # virtctl
    # kubernetes-helm
    # fluxcd
    argocd
    # telepresence2 # Local development against remote Kubernetes cluster
    # mirrord # Debug Kubernetes applications locally
    # kubefwd

    minikube # local kubernetes
  ];

  home.shellAliases = {
    k = "kubectl";
  };
}
