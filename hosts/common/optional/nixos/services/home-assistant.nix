{
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

      "lifx"
    ];
    extraPackages = ps: with ps; [psycopg2];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = {};

      recorder.db_url = "postgresql://@/hass";

      # Setup home assistant for nginx reverse proxy
      http = {
        server_host = "::1";
        trusted_proxies = ["::1"];
        use_x_forwarded_for = true;
      };

      # Import the ui configurations
      # "automation ui" = "!include automations.yaml";
      # "scene ui" = "!include scenes.yaml";
      # "script ui" = "!include scripts.yaml";
    };
  };

  services.nginx.virtualHosts."home-assistant.addg0.com" = {
    forceSSL = true;
    useACMEHost = "addg0.com";
    extraConfig = ''
      proxy_buffering off;
    '';
    locations."/" = {
      proxyPass = "http://[::1]:8123";
      proxyWebsockets = true;
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = ["hass"];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
      }
    ];
  };
}
