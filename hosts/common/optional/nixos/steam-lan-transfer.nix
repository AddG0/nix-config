# Opt-in: opens port 27040 for Steam LAN game transfers (needs programs.steam).
# Port alone does nothing — also enable per client:
# Steam > Settings > Downloads > "Allow downloads on your local network".
_: {
  programs.steam.localNetworkGameTransfers.openFirewall = true;
}
