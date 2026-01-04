# OpenTelemetry Collector for sending local telemetry to remote Grafana stack
# Uses OAuth2 client credentials flow for authentication
{
  config,
  inputs,
  pkgs,
  ...
}: let
  otlp-ingest = pkgs.writeShellApplication {
    name = "otlp-ingest";
    runtimeInputs = with pkgs; [curl jq coreutils findutils];
    text = builtins.readFile ./otlp-ingest.sh;
  };
in {
  environment.systemPackages = [otlp-ingest];

  # Create the user/group early so sops can set ownership
  users.users.opentelemetry-collector = {
    isSystemUser = true;
    group = "opentelemetry-collector";
  };
  users.groups.opentelemetry-collector = {};

  sops.secrets."otlp/client_secret" = {
    sopsFile = "${inputs.nix-secrets}/global/otlp.yaml";
    owner = "opentelemetry-collector";
    group = "opentelemetry-collector";
  };

  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    settings = {
      extensions = {
        oauth2client = {
          client_id = "otlp";
          client_secret_file = config.sops.secrets."otlp/client_secret".path;
          token_url = "https://auth.${config.hostSpec.domain}/realms/platform/protocol/openid-connect/token";
        };
      };

      receivers = {
        otlp = {
          protocols = {
            grpc.endpoint = "127.0.0.1:4317";
            http.endpoint = "127.0.0.1:4318";
          };
        };
      };

      exporters = {
        otlphttp = {
          endpoint = "https://otlp.addg0.com";
          auth.authenticator = "oauth2client";
        };
      };

      service = {
        extensions = ["oauth2client"];
        pipelines = {
          traces = {
            receivers = ["otlp"];
            exporters = ["otlphttp"];
          };
          logs = {
            receivers = ["otlp"];
            exporters = ["otlphttp"];
          };
          metrics = {
            receivers = ["otlp"];
            exporters = ["otlphttp"];
          };
        };
      };
    };
  };
}
