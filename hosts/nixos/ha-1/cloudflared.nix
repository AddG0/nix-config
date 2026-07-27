# Cloudflare Tunnel — the Fredericksburg WAN is Starlink CGNAT (100.64.0.0/10),
# so inbound WAN port-forwards can't reach this box; cloudflared dials out instead.
#
# One-time bootstrap (needs Cloudflare browser auth — can't be done in the build):
#   cloudflared tunnel login
#   cloudflared tunnel create ha-1                 # prints the UUID + creds JSON
#   cloudflared tunnel route dns ha-1 <vhost>      # CNAME <vhost> -> <uuid>.cfargotunnel.com
#   sops encrypt ~/.cloudflared/<uuid>.json > nix-secrets/services/cloudflared/ha-1.json.enc
# Then set tunnelId below to the UUID.
{
  config,
  inputs,
  lib,
  ...
}: let
  # UUID from `cloudflared tunnel create ha-1`. Not secret (the creds file is).
  tunnelId = "fcee14fd-0eb4-465a-89d3-ef7814b0b9bc";
in {
  sops.secrets."cloudflared-ha-1" = {
    sopsFile = "${inputs.nix-secrets}/services/cloudflared/ha-1.json.enc";
    format = "binary";
    owner = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      credentialsFile = config.sops.secrets."cloudflared-ha-1".path;
      default = "http_status:404";
      # HA listens on :8123; Cloudflare terminates public TLS, origin hop is local.
      ingress.${config.services.homeAssistantOci.hostName} = "http://localhost:8123";
    };
  };
}
