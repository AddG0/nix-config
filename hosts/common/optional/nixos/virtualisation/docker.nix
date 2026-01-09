{config, ...}: {
  virtualisation.docker.enable = true;

  # Required for Docker NAT to work with NixOS firewall
  networking.firewall.checkReversePath = "loose";

  # Fix for Docker/kind NAT - NixOS firewall flushes iptables rules on reload,
  # which removes Docker's masquerade rules. This ensures they get re-added.
  #
  # Debugging if NAT rules are missing:
  #   Check firewall reloads: journalctl -u firewall --since "1 hour ago"
  #   Check masquerade rules: sudo iptables-save | grep MASQUERADE
  #   Check nftables rules:   sudo nft list ruleset | grep masq
  #   Firewall script lives at: /nix/store/...-firewall-start/bin/firewall-start
  networking.nat = {
    enable = true;
    internalInterfaces = ["docker0" "br-+"];
    externalInterface = config.hostSpec.networking.hostsAddr.${config.hostSpec.hostName}.iface;
  };
}
