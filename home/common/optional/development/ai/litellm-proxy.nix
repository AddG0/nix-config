{
  config,
  lib,
  pkgs,
  ...
}: let
  # Local-only master key (not a real secret, just auth between proxy and client)
  masterKey = "sk-litellm-local-proxy-key";

  yaml = pkgs.formats.yaml {};

  # LiteLLM configuration with wildcard routing
  # Use provider/* pattern to forward all models automatically
  # Models without a prefix default to Anthropic
  litellmConfig = yaml.generate "litellm-config.yaml" {
    model_list = [
      # Gemini - all models via wildcard
      {
        model_name = "gemini/*";
        litellm_params = {
          model = "gemini/*";
          api_key = "os.environ/GEMINI_API_KEY";
        };
      }
      # OpenAI - all models via wildcard
      {
        model_name = "openai/*";
        litellm_params = {
          model = "openai/*";
          api_key = "os.environ/OPENAI_API_KEY";
        };
      }
      # Anthropic - all models via wildcard
      {
        model_name = "anthropic/*";
        litellm_params = {
          model = "anthropic/*";
          api_key = "os.environ/ANTHROPIC_API_KEY";
        };
      }
      # Default fallback - models without prefix go to Anthropic
      {
        model_name = "*";
        litellm_params = {
          model = "anthropic/*";
          api_key = "os.environ/ANTHROPIC_API_KEY";
        };
      }
    ];
    litellm_settings = {
      master_key = "os.environ/LITELLM_MASTER_KEY";
      drop_params = true;
    };
  };

  # Wrapper script to start LiteLLM proxy
  litellmProxy = pkgs.writeShellScriptBin "litellm-proxy" ''
    set -euo pipefail

    # Load secrets
    export GEMINI_API_KEY=$(cat ${config.sops.secrets."gemini/api_key".path})
    export OPENAI_API_KEY=$(cat ${config.sops.secrets."openai/api_key".path})
    export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."anthropic/api_key".path})
    export LITELLM_MASTER_KEY="${masterKey}"

    echo "Starting LiteLLM proxy on http://0.0.0.0:4000"
    echo ""
    echo "Wildcard routing enabled - all provider models supported:"
    echo "  gemini/*     - e.g. gemini/gemini-2.5-pro"
    echo "  openai/*     - e.g. openai/gpt-4o, openai/o1"
    echo "  anthropic/*  - e.g. anthropic/claude-sonnet-4-5-20250929"
    echo "  <no prefix>  - defaults to Anthropic (e.g. claude-sonnet-4-5-20250929)"
    echo ""
    echo "Usage: claude-lite --model <model-name>"
    echo ""

    exec ${lib.getExe pkgs.stable.litellm} --config ${litellmConfig} "$@"
  '';

  # Claude wrapper that uses LiteLLM proxy
  claudeLite = pkgs.writeShellScriptBin "claude-lite" ''
    set -euo pipefail

    export ANTHROPIC_BASE_URL="http://localhost:4000"
    export ANTHROPIC_AUTH_TOKEN="${masterKey}"

    exec claude "$@"
  '';
in {
  home.packages = [
    litellmProxy
    claudeLite
  ];
}
