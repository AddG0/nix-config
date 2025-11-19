{
  config,
  lib,
  ...
}: {
  imports = lib.custom.scanPaths ./.;

  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "analytics"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"
      # Recommended for fast zlib compression
      # https://www.home-assistant.io/integrations/isal
      "isal"

      "lifx" # TODO: Check working
    ];
    extraPackages = ps: with ps; [psycopg2];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = {};

      lifx = {};

      # Setup home assistant for nginx reverse proxy
      http = {
        server_host = "::1";
        trusted_proxies = ["::1"];
        use_x_forwarded_for = true;
      };

      homeassistant = {
        # MUST be at the top or will break entire configuration
        customize = {
          # Declare all "entity_id" objects here at this level to customize them
          "lifx.name" = {
            # Custom name however you want the entity to appear in the GUI
            friendly_name = "Uplift Light Strip";
            # See https://www.home-assistant.io/docs/configuration/customizing-devices/#icon for documentation
            icon = "mdi:lightbulb";
          };
        };
      };

      # Import the ui configurations
      # "automation ui" = "!include automations.yaml";
      # "scene ui" = "!include scenes.yaml";
      # "script ui" = "!include scripts.yaml";
      homeassistant = {
        customize = {
          # Declare all "entity_id" objects here at this level to customize them
          "lifx.name" = {
            # Custom name however you want the entity to appear in the GUI
            friendly_name = "Add's Uplift Light Strip";
            # See https://www.home-assistant.io/integrations/binary_sensor/ for documentation
            device_class = "deviceclass";
            # See https://www.home-assistant.io/docs/configuration/customizing-devices/#icon for documentation
            icon = "mdi:iconname";
          };
        };
      };
    };
  };

  services.nginx.virtualHosts."home-assistant.${config.hostSpec.domain}" = {
    forceSSL = true;
    useACMEHost = config.hostSpec.domain;
    extraConfig = ''
      proxy_buffering off;
    '';
    locations."/" = {
      proxyPass = "http://[::1]:8123";
      proxyWebsockets = true;
    };
  };
}
