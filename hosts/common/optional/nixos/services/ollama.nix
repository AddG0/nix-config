{
  lib,
  pkgs,
  config,
  ...
}: {
  # Browse models: https://ollama.com/library
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;

    host = lib.mkDefault "127.0.0.1";

    # Set default context window size (Ollama default is 4096).
    environmentVariables =
      {
        OLLAMA_CONTEXT_LENGTH = lib.mkDefault "65536";
      }
      // lib.optionalAttrs config.hostSpec.telemetry.enabled {
        OLLAMA_METRICS = "true";
      };
  };

  services.opentelemetry-collector.settings = lib.mkIf config.hostSpec.telemetry.enabled {
    receivers.prometheus = {
      config = {
        scrape_configs = [
          {
            job_name = "ollama";
            scrape_interval = "30s";
            static_configs = [{targets = ["localhost:11434"];}];
          }
        ];
      };
    };
    service.pipelines.metrics.receivers = ["otlp" "hostmetrics" "prometheus"];
  };
}
