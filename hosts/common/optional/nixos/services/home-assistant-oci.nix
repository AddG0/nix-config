# This command will pull the update home assistant to the latest version
# sudo podman pull ghcr.io/home-assistant/home-assistant:stable && sudo systemctl restart podman-homeassistant.service
{
  config,
  lib,
  ...
}: {
  options.services.homeAssistantOci = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "home-assistant.${config.hostSpec.domain}";
      description = "Host name the Home Assistant reverse proxy is served at.";
    };

    autoUpdate = {
      enable =
        lib.mkEnableOption "scheduled auto-updates of the Home Assistant container image via `podman auto-update`";

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        example = "*-*-* 04:00:00";
        description = "systemd OnCalendar expression controlling how often `podman auto-update` runs.";
      };
    };
  };

  config = let
    cfg = config.services.homeAssistantOci;
  in {
    virtualisation.oci-containers = {
      containers.homeassistant = {
        volumes = ["home-assistant:/config"];
        environment.TZ = config.time.timeZone;
        # Note: The image will not be updated on rebuilds, unless the version label changes
        image = "ghcr.io/home-assistant/home-assistant:stable";
        # Lets `podman auto-update` pull newer :stable images and restart this unit on a timer
        labels = lib.mkIf cfg.autoUpdate.enable {
          "io.containers.autoupdate" = "registry";
        };
        extraOptions = [
          "--network=host"
        ];
      };
    };

    systemd.services.homeassistant-auto-update = lib.mkIf cfg.autoUpdate.enable {
      description = "Auto-update the Home Assistant container image";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.virtualisation.podman.package}/bin/podman auto-update";
      };
    };

    systemd.timers.homeassistant-auto-update = lib.mkIf cfg.autoUpdate.enable {
      description = "Schedule Home Assistant container auto-updates";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.autoUpdate.schedule;
        Persistent = true;
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
