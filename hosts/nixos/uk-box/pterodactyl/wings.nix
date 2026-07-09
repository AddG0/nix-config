{config, ...}: {
  services.pterodactyl.wings = {
    enable = true;
    hostName = "wings-eu.${config.hostSpec.domain}";
    acmeHost = config.hostSpec.domain;
    settings = {
      api = {
        ssl.enabled = false;
        port = 8080;
      };
      remote = config.services.pterodactyl.panel.url;
    };
  };

  security.firewall.allowedTCPPorts = [2022 25565 25566 25567 25568 25569 25570 24454 24455 24456];
}
