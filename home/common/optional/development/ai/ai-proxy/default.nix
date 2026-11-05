# Claude Code and Codex through ai-proxy on asgard, both signed in by this helper (gitops ADR-0010, ADR-0040).
{
  config,
  lib,
  pkgs,
  ...
}: let
  issuer = "https://auth.${config.hostSpec.domain}";
  baseUrl = "https://ai-proxy.${config.hostSpec.domain}";
  claudeUrl = account: "https://ai-proxy-claude-${account}.${config.hostSpec.domain}";

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
      AI_PROXY_CLAUDE_DEFAULT_URL = claudeUrl "personal";
      # A file, not the JSON itself: writeShellApplication shellchecks its env lines, and quotes in a value fail SC2089.
      AI_PROXY_CLAUDE_ROUTES_FILE = (pkgs.formats.json {}).generate "ai-proxy-claude-routes.json" (lib.mapAttrs (_: claudeUrl) config.ai-proxy.claude.routes);
      # The project audience is what the gateway checks, offline_access yields a refresh token, and profile/email name you in `ai-proxy status`.
      AI_PROXY_SCOPE = "openid profile email offline_access urn:zitadel:iam:org:project:id:${projectId}:aud";
    };
    text = builtins.readFile ./ai-proxy.sh;
  };

  codex = import ./codex-wrapper.nix {
    inherit pkgs;
    aiProxy = ai-proxy;
    inherit (pkgs) codex;
  };

  claudeProxySettings = (pkgs.formats.json {}).generate "claude-ai-proxy-settings.json" {
    apiKeyHelper = "${lib.getExe ai-proxy} token";
    disableClaudeAiConnectors = true;
  };

  opencodeProvider = "ai-proxy";
in {
  options.ai-proxy.claude.routes = lib.mkOption {
    type = lib.types.attrsOf (lib.types.enum ["personal" "work"]);
    default = {};
    example = {"/home/me/Projects/code/gitlab.com/acme" = "work";};
    description = "Directories whose Claude Code sessions use the named account's host; the deepest root holding the session wins, and a session under none uses personal.";
  };

  config = {
    assertions = [
      {
        assertion = config.hostSpec.hostType != "server";
        message = "ai-proxy logs in with a browser device code, which a headless host can't complete; it needs a service account from infra-live's ai_proxy_keys instead.";
      }
      {
        assertion = lib.all (lib.hasPrefix "/") (lib.attrNames config.ai-proxy.claude.routes);
        message = "ai-proxy.claude.routes keys must be absolute directories, as a session resolves them from wherever it starts; got: ${lib.concatStringsSep ", " (lib.attrNames config.ai-proxy.claude.routes)}";
      }
    ];

    home.packages = [ai-proxy];

    # It would outrank apiKeyHelper, and secrets/ai exports it into zsh for codecompanion.
    programs.claude-code-profiles.unsetEnv = ["ANTHROPIC_API_KEY"];

    programs.claude-code-profiles.conditionalSettings = {
      command = "${lib.getExe ai-proxy} ready claude";
      file = claudeProxySettings;
    };

    programs.codex = {
      package = codex;
      settings.model_providers.ai-proxy = {
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

    # Only the general host: the Claude one admits nothing but Claude Code (gitops ADR-0010).
    programs.opencode.settings.provider.${opencodeProvider} = {
      npm = "@ai-sdk/openai";
      name = "AI Proxy";
      options = {
        baseURL = "${baseUrl}/v1";
        # The SDK refuses to send without a key; the plugin's Authorization header replaces it.
        apiKey = "ai-proxy";
      };
    };

    xdg.configFile."opencode/plugins/ai-proxy.js".source = pkgs.replaceVars ./opencode-plugin.js {
      helper = lib.getExe ai-proxy;
      provider = opencodeProvider;
    };
  };
}
