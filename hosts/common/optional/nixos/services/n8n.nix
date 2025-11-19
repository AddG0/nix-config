{config, ...}: {
  services.n8n = {
    enable = true;
    openFirewall = true;
    environment = {
      WEBHOOK_URL = "https://n8n.${config.hostSpec.domain}/";
      N8N_HOST = "0.0.0.0";
    };
  };

  services.nginx.virtualHosts."n8n.${config.hostSpec.domain}" = {
    forceSSL = true;
    useACMEHost = config.hostSpec.domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.n8n.environment.N8N_PORT}";
      proxyWebsockets = true;
    };
  };
}
