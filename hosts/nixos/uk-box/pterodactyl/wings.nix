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

  security.firewall = {
    # 2022 SFTP
    # 25565-25570 Minecraft
    # 24454-24456 Voice Chat
    # 7777-7779 & 8888-8890 Satisfactory
    allowedTCPPorts = [2022 25565 25566 25567 25568 25569 25570 24454 24455 24456 7777 7778 7779 8888 8889 8890];
    allowedUDPPorts = [7777 7778 7779];
  };
}
