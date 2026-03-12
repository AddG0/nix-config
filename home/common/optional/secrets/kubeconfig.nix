{
  config,
  inputs,
  hostSpec,
  ...
}: {
  sops.secrets = {
    kube_config = {
      format = "binary";
      sopsFile = "${inputs.nix-secrets}/users/${hostSpec.username}/kube-config.enc";
      mode = "0600";
      path = "${config.home.homeDirectory}/.kube/config-personal";
    };
  };

  home.sessionVariables = {
    KUBECONFIG = "${config.home.homeDirectory}/.kube/config:${config.sops.secrets.kube_config.path}";
  };
}
