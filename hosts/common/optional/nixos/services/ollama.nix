{pkgs, ...}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;

    # Bind to localhost only (use "0.0.0.0" to expose to LAN)
    host = "127.0.0.1";

    # Optional: preload models at startup
    loadModels = ["qwen2.5:32b"];
  };
}
