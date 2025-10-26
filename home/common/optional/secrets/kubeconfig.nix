{
  config,
  nix-secrets,
  ...
}: {
  sops.secrets = {
    kube_config = {
      format = "binary";
      sopsFile = "${nix-secrets}/secrets/kube.yaml.enc";
      mode = "0600";
      path = "${config.home.homeDirectory}/.kube/config-home";
    };
  };

  programs.zsh.initContent = ''
    export KUBECONFIG=${config.home.homeDirectory}/.kube/config:${config.sops.secrets.kube_config.path}
  '';
}
