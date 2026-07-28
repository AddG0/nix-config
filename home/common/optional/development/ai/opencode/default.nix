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

  # Auto-populate the Ollama model picker from the live `ollama list`.
  xdg.configFile."opencode/plugin/ollama-autodiscover.js".source = ./plugins/ollama-autodiscover.js;

  programs.code-assistant-profiles.targets.opencode.enable = true;

  programs.opencode = {
    enable = true;
    package = opencodeWrapped;
    tui.theme = lib.mkDefault "catppuccin";
    settings.autoupdate = false;
    settings.experimental.openTelemetry = telemetryEnabled;
    settings.provider.ollama = {
      # Models are discovered at runtime by the ollama-autodiscover plugin.
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama (local)";
      options.baseURL = "http://localhost:11434/v1";
    };
  };
}
