# This command will pull the update home assistant to the latest version
# sudo podman pull ghcr.io/home-assistant/home-assistant:stable && sudo systemctl restart podman-homeassistant.service
{
  config,
  lib,
  ...
}: {
  options.services.homeAssistantOci.hostName = lib.mkOption {
    type = lib.types.str;
    default = "home-assistant.${config.hostSpec.domain}";
    description = "Host name the Home Assistant reverse proxy is served at.";
  };

  config = {
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

    services.nginx.virtualHosts.${config.services.homeAssistantOci.hostName} = {
      forceSSL = true;
      useACMEHost = config.hostSpec.domain;
      extraConfig = ''
        proxy_buffering off;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true;
      };
    };

    security.firewall.allowedTCPPorts = [8123];
  };
}
