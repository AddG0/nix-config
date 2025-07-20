{config, ...}: {
  services.n8n = {
    enable = true;
    openFirewall = true;
  };

  services.nginx.virtualHosts."n8n.addg0.com" = {
    forceSSL = true;
    useACMEHost = "addg0.com";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.n8n.settings.port}";
      proxyWebsockets = true;
    };
  };

  networking.hosts = {
    "127.0.0.1" = ["n8n.addg0.com"];
  };
}
