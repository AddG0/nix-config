{
  config,
  nix-secrets,
  ...
}: {
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    enableReload = true;
    serverTokens = false;

    # ACME + DNS challenge via Cloudflare
    clientMaxBodySize = "50m";

    virtualHosts = {
      "block-default" = {
        default = true;
        extraConfig = ''
          server_name "";
          return 444;
        '';
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = config.hostSpec.email.user;
    certs."${config.hostSpec.domain}" = {
      dnsProvider = "cloudflare";
      credentialFiles."CF_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare.path;
      group = "nginx";
      postRun = "systemctl --no-block reload nginx.service";
      extraDomainNames = ["*.${config.hostSpec.domain}"];
    };
  };

  sops.secrets.cloudflare = {
    format = "binary";
    sopsFile = "${nix-secrets}/global/api-keys/cloudflare.enc";
    mode = "0400";
    owner = "root";
  };

  security.firewall.allowedTCPPorts = [80 443];
}
