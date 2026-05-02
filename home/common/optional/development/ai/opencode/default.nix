{lib, ...}: {
  stylix.targets.opencode.enable = lib.mkDefault false;

  programs.opencode = {
    enable = true;
    tui.theme = lib.mkDefault "catppuccin";
    settings.autoupdate = false;
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
