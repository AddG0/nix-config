{
  pkgs,
  nur-ryan4yin,
  ...
}: {
  home.packages = with pkgs; [
    docker-compose
    dive # explore docker layers
    lazydocker # Docker terminal UI.
    skopeo # copy/sync images between registries and local storage
    go-containerregistry # provides `crane` & `gcrane`, it's similar to skopeo

    kubectl
    kustomize_4
    kubectx
    kubebuilder
    kubevpn
    telepresence2
    helmfile
    istioctl
    clusterctl # for kubernetes cluster-api
    kubevirt # virtctl
    kubernetes-helm
    fluxcd
    argocd
    telepresence2 # Local development against remote Kubernetes cluster
    mirrord # Debug Kubernetes applications locally
    kubefwd

    ko # build go project to container image

    minikube # local kubernetes
  ];
}
