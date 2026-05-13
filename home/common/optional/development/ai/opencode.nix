{
  config,
  lib,
  pkgs,
  ...
}: let
  telemetryEnabled = config.hostSpec.telemetry.enabled && config.hostSpec.telemetry.opencode.enabled;
  opencodeWrapped = pkgs.symlinkJoin {
    name = "opencode-wrapped";
    paths = [pkgs.opencode];
    buildInputs = [pkgs.makeWrapper];
    postBuild = lib.optionalString telemetryEnabled ''
      wrapProgram $out/bin/opencode \
        --set OTEL_EXPORTER_OTLP_ENDPOINT http://localhost:4318 \
        --set OTEL_RESOURCE_ATTRIBUTES host.name=${config.hostSpec.hostName}
    '';
  };
in {
  stylix.targets.opencode.enable = lib.mkDefault false;

  programs.code-assistant-profiles.targets.opencode.enable = true;

  programs.opencode = {
    enable = true;
    package = opencodeWrapped;
    tui.theme = lib.mkDefault "catppuccin";
    settings.autoupdate = false;
    settings.experimental.openTelemetry = telemetryEnabled;
    settings.provider.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama (local)";
      options.baseURL = "http://localhost:11434/v1";
      models."gemma4".name = "Gemma 4 31B";
      models."qwen3.5:27b".name = "Qwen 3.5 27B";
      models."qwen3.5:35b".name = "Qwen 3.5 35B-A3B";
    };
  };
}
