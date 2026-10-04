# Claude Code and Codex through ai-proxy on asgard, both signed in by this helper (gitops ADR-0010).
{
  config,
  lib,
  pkgs,
  ...
}: let
  issuer = "https://auth.${config.hostSpec.domain}";
  baseUrl = "https://ai-proxy.${config.hostSpec.domain}";
  claudeUrl = "https://ai-proxy-claude.${config.hostSpec.domain}";

  # infra-live's `tofu output ai_proxy`; prevent_destroy there keeps both from changing.
  projectId = "393364980939882573";
  clientId = "393364981443264589";

  ai-proxy = pkgs.writeShellApplication {
    name = "ai-proxy";
    runtimeInputs = with pkgs; [coreutils curl flock jq];
    runtimeEnv = {
      AI_PROXY_ISSUER = issuer;
      AI_PROXY_CLIENT_ID = clientId;
      AI_PROXY_URL = baseUrl;
      AI_PROXY_CLAUDE_URL = claudeUrl;
      # The project audience is what the gateway checks, offline_access yields a refresh token, and profile/email name you in `ai-proxy status`.
      AI_PROXY_SCOPE = "openid profile email offline_access urn:zitadel:iam:org:project:id:${projectId}:aud";
    };
    text = builtins.readFile ./ai-proxy.sh;
  };
in {
  assertions = [
    {
      assertion = config.hostSpec.hostType != "server";
      message = "ai-proxy logs in with a browser device code, which a headless host can't complete; it needs a service account from infra-live's ai_proxy_keys instead.";
    }
  ];

  home.packages = [ai-proxy];

  # It would outrank apiKeyHelper, and secrets/ai exports it into zsh for codecompanion.
  programs.claude-code-profiles.unsetEnv = ["ANTHROPIC_API_KEY"];

  programs.claude-code-profiles.baseConfig.settings = {
    apiKeyHelper = "${lib.getExe ai-proxy} token";
    # They need a claude.ai login, which apiKeyHelper outranks.
    disableClaudeAiConnectors = true;
    env.ANTHROPIC_BASE_URL = claudeUrl;
  };

  programs.codex.settings = {
    model_provider = "ai-proxy";
    model_providers.ai-proxy = {
      name = "ai-proxy";
      base_url = "${baseUrl}/v1";
      wire_api = "responses";
      auth = {
        command = lib.getExe ai-proxy;
        args = ["token"];
        refresh_interval_ms = 300000;
      };
    };
  };
}
