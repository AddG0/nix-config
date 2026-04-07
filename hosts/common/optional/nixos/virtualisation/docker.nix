{...}: {
  virtualisation.docker.enable = true;

  # After a firewall reload, Docker's per-network iptables masquerade rules
  # get flushed. partOf ensures Docker restarts to re-add them.
  # Note: this will restart running containers on firewall reload.
  # See: https://github.com/moby/moby/issues/12294
  systemd.services.docker.after = ["firewall.service"];
  systemd.services.docker.partOf = ["firewall.service"];

  # Required for Docker NAT to work with NixOS firewall
  networking.firewall.checkReversePath = "loose";
}
