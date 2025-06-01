{config, ...}: {
  virtualisation.oci-containers = {
    containers.homeassistant = {
      volumes = ["home-assistant:/config"];
      environment.TZ = config.time.timeZone;
      # Note: The image will not be updated on rebuilds, unless the version label changes
      image = "ghcr.io/home-assistant/home-assistant:stable";
      extraOptions = [
        "--network=host"
      ];
    };
  };

  services.nginx.virtualHosts."home-assistant.addg0.com" = {
    forceSSL = true;
    useACMEHost = "addg0.com";
    extraConfig = ''
      proxy_buffering off;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:8123";
      proxyWebsockets = true;
    };
  };

  security.firewall.allowedTCPPorts = [8123];
}
