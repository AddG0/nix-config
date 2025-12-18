{pkgs, ...}: let
  # kubectl-cloud-shell script and completions
  kubectl-cloud-shell-script = pkgs.writeShellApplication {
    name = "kubectl-cloud-shell";
    runtimeInputs = [pkgs.kubectl];
    text = builtins.readFile ./scripts/kubectl-cloud-shell.sh;
  };

  kubectl-cloud-shell-zsh-completion = pkgs.writeTextFile {
    name = "kubectl-cloud-shell-zsh-completion";
    destination = "/share/zsh/site-functions/_kubectl-cloud-shell";
    text = builtins.readFile ./scripts/kubectl-cloud-shell-completion.zsh;
  };

  kubectl-cloud-shell-nu-completion = pkgs.writeTextFile {
    name = "kubectl-cloud-shell-nu-completion";
    destination = "/share/nushell/vendor/autoload/kubectl-cloud-shell.nu";
    text = builtins.readFile ./scripts/kubectl-cloud-shell-completion.nu;
  };

  kubectl-cloud-shell = pkgs.symlinkJoin {
    name = "kubectl-cloud-shell";
    paths = [
      kubectl-cloud-shell-script
      kubectl-cloud-shell-zsh-completion
      kubectl-cloud-shell-nu-completion
    ];
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

    istioctl
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

  programs.nushell.extraConfig = ''
    # kubectl-cloud-shell completions
    source ${kubectl-cloud-shell}/share/nushell/vendor/autoload/kubectl-cloud-shell.nu
  '';

  # Disable Kind container auto-start at boot
  # This allows using `docker start` manually instead
  systemd.user.services.kind-disable-autostart = {
    Unit = {
      Description = "Disable Kind container auto-start";
      After = ["docker.service"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker ps -a --filter label=io.x-k8s.kind.cluster --format {{.Names}} | xargs -r ${pkgs.docker}/bin/docker update --restart=no'";
    };
    Install.WantedBy = ["default.target"];
  };
}
