{pkgs, ...}: let
  # kubectl-cloud-shell script and completions
  kubectl-cloud-shell-script = pkgs.writeShellApplication {
    name = "kubectl-cloud-shell";
    runtimeInputs = [pkgs.kubectl pkgs.socat];
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

  # kind-start script and completions
  kind-start-script = pkgs.writeShellApplication {
    name = "kind-start";
    runtimeInputs = [pkgs.docker pkgs.kind pkgs.kubectl pkgs.gnused];
    text = builtins.readFile ./scripts/kind-start.sh;
  };

  kind-start-zsh-completion = pkgs.writeTextFile {
    name = "kind-start-zsh-completion";
    destination = "/share/zsh/site-functions/_kind-start";
    text = builtins.readFile ./scripts/kind-start-completion.zsh;
  };

  kind-start-nu-completion = pkgs.writeTextFile {
    name = "kind-start-nu-completion";
    destination = "/share/nushell/vendor/autoload/kind-start.nu";
    text = builtins.readFile ./scripts/kind-start-completion.nu;
  };

  kind-start = pkgs.symlinkJoin {
    name = "kind-start";
    paths = [
      kind-start-script
      kind-start-zsh-completion
      kind-start-nu-completion
    ];
  };

  # kind-stop script and completions
  kind-stop-script = pkgs.writeShellApplication {
    name = "kind-stop";
    runtimeInputs = [pkgs.docker pkgs.gnused];
    text = builtins.readFile ./scripts/kind-stop.sh;
  };

  kind-stop-zsh-completion = pkgs.writeTextFile {
    name = "kind-stop-zsh-completion";
    destination = "/share/zsh/site-functions/_kind-stop";
    text = builtins.readFile ./scripts/kind-stop-completion.zsh;
  };

  kind-stop-nu-completion = pkgs.writeTextFile {
    name = "kind-stop-nu-completion";
    destination = "/share/nushell/vendor/autoload/kind-stop.nu";
    text = builtins.readFile ./scripts/kind-stop-completion.nu;
  };

  kind-stop = pkgs.symlinkJoin {
    name = "kind-stop";
    paths = [
      kind-stop-script
      kind-stop-zsh-completion
      kind-stop-nu-completion
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
    kind-start
    kind-stop
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
    # kind-start completions
    source ${kind-start}/share/nushell/vendor/autoload/kind-start.nu
    # kind-stop completions
    source ${kind-stop}/share/nushell/vendor/autoload/kind-stop.nu
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
