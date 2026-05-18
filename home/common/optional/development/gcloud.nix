# Application Default Credentials (ADC) — used by client libraries / SDKs
# -----------------------------------------------------------------------
# ADC is a single global file (~/.config/gcloud/application_default_credentials.json)
# and is independent of gcloud's active account. Refresh with:
#   gcloud auth application-default login
#
# To isolate two accounts (e.g. work vs personal), point CLOUDSDK_CONFIG at a
# per-account dir in each shell — gcloud creds AND ADC live under it. Also set
# GOOGLE_APPLICATION_CREDENTIALS, since SDKs (e.g. Go-based) ignore CLOUDSDK_CONFIG:
#   export CLOUDSDK_CONFIG=$HOME/.config/gcloud-work
#   export GOOGLE_APPLICATION_CREDENTIALS=$CLOUDSDK_CONFIG/application_default_credentials.json
#   gcloud auth login && gcloud auth application-default login   # one-time
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
