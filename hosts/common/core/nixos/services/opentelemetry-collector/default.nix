# OpenTelemetry Collector for sending local telemetry to remote Grafana stack
# Uses OAuth2 client credentials flow for authentication
# Enabled conditionally via hostSpec.telemetry.enabled
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.hostSpec.telemetry;

  otlp-ingest = pkgs.writeShellApplication {
    name = "otlp-ingest";
    runtimeInputs = with pkgs; [curl jq coreutils findutils];
    text = builtins.readFile ./otlp-ingest.sh;
  };
in {
  config = lib.mkIf cfg.enabled {
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

          # Host metrics collector for system telemetry
          hostmetrics = {
            collection_interval = "30s";
            scrapers = {
              cpu = {
                metrics = {
                  "system.cpu.utilization".enabled = true;
                };
              };
              memory = {
                metrics = {
                  "system.memory.utilization".enabled = true;
                };
              };
              disk = {};
              filesystem = {};
              network = {};
              load = {};
              paging = {};
              processes = {};
            };
          };
        };

        processors = {
          # Add host metadata to all telemetry
          resourcedetection = {
            detectors = ["system"];
            system = {
              hostname_sources = ["os"];
              resource_attributes = {
                "host.name".enabled = true;
                "host.id".enabled = true;
                "os.type".enabled = true;
              };
            };
          };

          # Batch telemetry for efficiency
          batch = {
            timeout = "10s";
            send_batch_size = 1000;
          };
        };

        exporters = {
          otlphttp = {
            endpoint = "https://otlp.addg0.com";
            auth.authenticator = "oauth2client";
            # Retry on transient failures
            retry_on_failure = {
              enabled = true;
              initial_interval = "1s";
              max_interval = "30s";
              max_elapsed_time = "5m";
            };
            # Queue to buffer during transient failures
            sending_queue = {
              enabled = true;
              num_consumers = 10;
              queue_size = 1000;
            };
          };
        };

        service = {
          telemetry = {
            metrics = {
              readers = [
                {
                  pull = {
                    exporter = {
                      prometheus = {
                        host = "127.0.0.1";
                        port = 19888;
                      };
                    };
                  };
                }
              ];
            };
          };
          extensions = ["oauth2client"];
          pipelines = {
            traces = {
              receivers = ["otlp"];
              processors = ["resourcedetection" "batch"];
              exporters = ["otlphttp"];
            };
            logs = {
              receivers = ["otlp"];
              processors = ["resourcedetection" "batch"];
              exporters = ["otlphttp"];
            };
            metrics = {
              receivers = ["otlp" "hostmetrics"];
              processors = ["resourcedetection" "batch"];
              exporters = ["otlphttp"];
            };
          };
        };
      };
    };
  };
}
