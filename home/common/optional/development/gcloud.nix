{pkgs, ...}: {
  home.packages = with pkgs; [
    google-cloud-sdk
    gke-gcloud-auth-plugin
  ];

  # gcloud CLI completions - bash completions are auto-loaded by home-manager
  # For zsh, use bash completion via bashcompinit
  programs.zsh.initContent = ''
    # Enable bash completion compatibility for gcloud
    autoload -U +X bashcompinit && bashcompinit
    source "${pkgs.google-cloud-sdk}/share/bash-completion/completions/gcloud"
  '';
}
