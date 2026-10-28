{
  lib,
  pkgs,
  ...
}: {
  # Browse models: https://ollama.com/library
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;

    host = lib.mkDefault "127.0.0.1";

    # Set default context window size (Ollama default is 4096).
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = lib.mkDefault "65536";
    };
  };
}
