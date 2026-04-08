{lib, ...}: {
  imports = [./adapter.nix];

  programs.opencode = {
    enable = true;
    settings.theme = lib.mkDefault "catppuccin";
    settings.autoupdate = false;
    settings.provider.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama (local)";
      options.baseURL = "http://localhost:11434/v1";
      models."qwen2.5-coder:32b".name = "Qwen 2.5 Coder 32B";
    };
  };
}
