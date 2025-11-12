{
  config,
  nix-secrets,
  inputs,
  ...
}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = "${nix-secrets}/users/${config.hostSpec.username}/personal.yaml";
    age = {
      sshKeyPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];
      keyFile = "${config.home.homeDirectory}/.config/sops-nix/age/keys.txt";
      generateKey = true;
    };
  };

  sops.secrets = {
    "personal_accounts/github_personal_token" = {};
    "openai/api_key" = {
      sopsFile = "${nix-secrets}/global/api-keys/ai.yaml";
    };
    "langchain/api_key" = {
      sopsFile = "${nix-secrets}/global/api-keys/ai.yaml";
    };
    "tavily/api_key" = {
      sopsFile = "${nix-secrets}/global/api-keys/search.yaml";
    };
    "anthropic/api_key" = {
      sopsFile = "${nix-secrets}/global/api-keys/ai.yaml";
    };
  };

  programs.zsh.initContent = ''
    export GITHUB_TOKEN=$(cat ${config.sops.secrets."personal_accounts/github_personal_token".path})
    export SOPS_AGE_KEY_FILE=~/.config/sops-nix/age/keys.txt
    export OPENAI_API_KEY=$(cat ${config.sops.secrets."openai/api_key".path})
    export LANGCHAIN_API_KEY=$(cat ${config.sops.secrets."langchain/api_key".path})
    export TAVILY_API_KEY=$(cat ${config.sops.secrets."tavily/api_key".path})
    export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."anthropic/api_key".path})
  '';

  # This is so I can use sops in the shell anywhere
  # home.file.".sops.yaml" = {
  #   source = "${nix-secrets}/.sops.yaml";
  # };
}
