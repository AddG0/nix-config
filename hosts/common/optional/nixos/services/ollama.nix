{pkgs, ...}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;

    # Bind to localhost only (use "0.0.0.0" to expose to LAN)
    host = "127.0.0.1";

    # Set default context window size (default is 2048)
    environmentVariables = {
      OLLAMA_NUM_CTX = "32768";
    };
  };
}
