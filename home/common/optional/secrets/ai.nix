{
  config,
  inputs,
  ...
}: {
  sops.secrets = {
    "openai/api_key" = {
      sopsFile = "${inputs.nix-secrets}/global/api-keys/ai.yaml";
    };
    "langchain/api_key" = {
      sopsFile = "${inputs.nix-secrets}/global/api-keys/ai.yaml";
    };
    "tavily/api_key" = {
      sopsFile = "${inputs.nix-secrets}/global/api-keys/search.yaml";
    };
    "anthropic/api_key" = {
      sopsFile = "${inputs.nix-secrets}/global/api-keys/ai.yaml";
    };
    "gemini/api_key" = {
      sopsFile = "${inputs.nix-secrets}/global/api-keys/ai.yaml";
    };
  };

  programs.zsh.initContent = ''
    export OPENAI_API_KEY=$(cat ${config.sops.secrets."openai/api_key".path})
    export LANGCHAIN_API_KEY=$(cat ${config.sops.secrets."langchain/api_key".path})
    export TAVILY_API_KEY=$(cat ${config.sops.secrets."tavily/api_key".path})
    export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."anthropic/api_key".path})
    export GEMINI_API_KEY=$(cat ${config.sops.secrets."gemini/api_key".path})
  '';

  # This is so I can use sops in the shell anywhere
  home.file.".sops.yaml" = {
    source = ./.sops.yaml;
  };
}
