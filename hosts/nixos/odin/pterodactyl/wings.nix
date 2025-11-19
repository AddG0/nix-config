{config, ...}: {
  services.pterodactyl.wings = {
    enable = true;
    settings = {
      api = {
        ssl.enabled = false;
        port = 8080;
      };
      remote = "https://pterodactyl.${config.hostSpec.domain}";
    };
  };

  services.nginx.virtualHosts."wings.${config.hostSpec.domain}" = {
    forceSSL = true;
    useACMEHost = config.hostSpec.domain;

    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
      '';
    };
  };

  networking.hosts = {
    "127.0.0.1" = ["wings.${config.hostSpec.domain}"];
  };

  networking.firewall.allowedTCPPorts = [2022 25565 25566 25567 25568 25569 25570 24454 24455 24456];
}
