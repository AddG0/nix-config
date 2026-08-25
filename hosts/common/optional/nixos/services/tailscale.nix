{config, ...}: {
  services.tailscale = {
    enable = true;

    # Serve and Funnel config is a root-only write until an operator is named.
    extraSetFlags = ["--operator=${config.hostSpec.primaryUsername}"];
  };
}
