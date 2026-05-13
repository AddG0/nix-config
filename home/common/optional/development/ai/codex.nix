{
  config,
  lib,
  ...
}: let
  telemetryEnabled = config.hostSpec.telemetry.enabled && config.hostSpec.telemetry.codex.enabled;
  otlpGrpcExporter."otlp-grpc".endpoint = "http://127.0.0.1:4317";
in {
  programs.code-assistant-profiles.targets.codex.enable = true;

  programs.codex = {
    enable = true;
    settings =
      {
        check_for_update_on_startup = false;
        tui = {
          theme = "catppuccin-mocha";
          status_line = [
            "model-with-reasoning"
            "context-remaining"
            "git-branch"
            "current-dir"
          ];
        };

        # Training/data-use controls are account/workspace settings, not config.toml keys.
        # See https://chatgpt.com/codex/settings/general and OpenAI's data controls.
        analytics.enabled = false;
        feedback.enabled = false;
      }
      // lib.optionalAttrs telemetryEnabled {
        otel = {
          environment = config.hostSpec.hostName;
          exporter = otlpGrpcExporter;
          metrics_exporter = otlpGrpcExporter;
          trace_exporter = otlpGrpcExporter;
          log_user_prompt = false;
        };
      };
  };
}
