{config, ...}: {
  services.pterodactyl.wings = {
    enable = true;
    hostName = "wings-eu.${config.hostSpec.domain}";
    acmeHost = config.hostSpec.domain;
    # ARK maps share obelisk transfers through this folder via a panel Mount
    allowedMounts = ["/var/lib/ark-cluster"];
    settings = {
      api = {
        ssl.enabled = false;
        port = 8080;
      };
      remote = config.services.pterodactyl.panel.url;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/ark-cluster 0750 ${config.services.pterodactyl.wings.user} ${config.services.pterodactyl.wings.group} -"
  ];

  networking.firewall = {
    # 2022 SFTP
    # 25565-25570 Minecraft
    # 24454-24456 Voice Chat
    # 7777-7779 & 8888-8890 Satisfactory
    # 7790-7795 & 27015-27017 ARK: Survival Evolved (game+raw per map, query)
    allowedTCPPorts = [2022 25565 25566 25567 25568 25569 25570 24454 24455 24456 7777 7778 7779 8888 8889 8890];
    allowedUDPPorts = [7777 7778 7779 7790 7791 7792 7793 7794 7795 27015 27016 27017];
  };
}
