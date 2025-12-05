{pkgs, ...}: let
  kubectl-cloud-shell-script = pkgs.writeShellApplication {
    name = "kubectl-cloud-shell";
    runtimeInputs = [pkgs.kubectl];
    text = builtins.readFile ./kubectl-cloud-shell.sh;
  };

  kubectl-cloud-shell-completion = pkgs.writeTextFile {
    name = "kubectl-cloud-shell-completion";
    destination = "/share/zsh/site-functions/_kubectl-cloud-shell";
    text = ''
      #compdef kubectl-cloud-shell

      _kubectl-cloud-shell() {
        local context state line
        typeset -A opt_args

        _arguments -C \
          '--bare[Use bare mode with minimal zsh setup instead of home-manager]' \
          '*:: :->kubectl_args'

        if [[ $state == kubectl_args ]]; then
          # Prepend "kubectl run pod-name" to simulate kubectl run completion
          words=( kubectl run pod-name "''${words[@]}" )
          # Adjust CURRENT: add 3 for the 3 new words we prepended
          (( CURRENT = CURRENT + 3 ))

          # Restart completion with the simulated command line
          _normal
        fi
      }

      _kubectl-cloud-shell "$@"
    '';
  };

  kubectl-cloud-shell = pkgs.symlinkJoin {
    name = "kubectl-cloud-shell";
    paths = [kubectl-cloud-shell-script kubectl-cloud-shell-completion];
  };
in {
  home.packages = with pkgs; [
    kubectl
    kustomize_4
    # kubectx
    # kubebuilder
    # kubevpn
    helmfile
    kubernetes-helm
    kubie

    # istioctl
    # clusterctl # for kubernetes cluster-api
    # kubevirt # virtctl
    # fluxcd
    argocd
    # telepresence2 # Local development against remote Kubernetes cluster
    # mirrord # Debug Kubernetes applications locally
    # kubefwd

    # minikube # local kubernetes
    kind

    # Custom scripts
    kubectl-cloud-shell
  ];

  programs.zsh.oh-my-zsh.plugins = [
    "helm"
    "kubectl"
    #  "microk8s"
    # "minikube"
  ];

  home.shellAliases = {
    k = "kubectl";
  };
}
