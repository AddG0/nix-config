{config, ...}: {
  services.n8n = {
    enable = true;
    openFirewall = true;
    environment = {
      WEBHOOK_URL = "https://n8n.addg0.com/";
      N8N_HOST = "0.0.0.0";
    };
  };

  services.nginx.virtualHosts."n8n.addg0.com" = {
    forceSSL = true;
    useACMEHost = "addg0.com";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.n8n.environment.N8N_PORT}";
      proxyWebsockets = true;
    };
  };
}
