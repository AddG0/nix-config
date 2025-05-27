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
        default = true; # ← makes this the default_server
        listen = [":80" "[::]:80"]; # ← HTTP on all interfaces
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
    certs."addg0.com" = {
      dnsProvider = "cloudflare";
      credentialsFile = config.sops.secrets.cloudflare.path;
      group = "nginx";
      postRun = "systemctl --no-block reload nginx.service";
      extraDomainNames = ["*.addg0.com"];
    };
  };

  sops.secrets.cloudflare = {
    format = "binary";
    sopsFile = "${nix-secrets}/secrets/cloudflare.env.enc";
    mode = "0400";
    owner = "root";
  };

  security.firewall.allowedTCPPorts = [80 443];
}
