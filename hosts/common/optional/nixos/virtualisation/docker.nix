_: {
  virtualisation.docker.enable = true;

  # Required for Docker NAT to work with NixOS firewall
  networking.firewall.checkReversePath = "loose";
}
