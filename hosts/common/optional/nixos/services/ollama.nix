{pkgs, ...}: {
  # Browse models: https://ollama.com/library
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;

    # Bind to localhost only (use "0.0.0.0" to expose to LAN)
    host = "127.0.0.1";

    # Set default context window size (Ollama default is 4096).
    # Override per-call with `ollama run <model> --num-ctx N` or API `options.num_ctx`.
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "65536";
    };
  };
}
