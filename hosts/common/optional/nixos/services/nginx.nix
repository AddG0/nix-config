{ config, nix-secrets, ...}: {
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    enableReload = true;
    serverTokens = false;

    # ACME + DNS challenge via Cloudflare
    clientMaxBodySize = "50m";
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = config.hostSpec.email.user;
    certs."addg0.com" = {
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets.cloudflare.path;
      group = "nginx";
      postRun = "systemctl --no-block reload nginx.service";
      extraDomainNames = [ "*.addg0.com" ];
    };
  };

  sops.secrets.cloudflare = {
    format = "binary";
    sopsFile = "${nix-secrets}/secrets/cloudflare.env.enc";
    mode = "0400";
    owner = "root";
  };
}
