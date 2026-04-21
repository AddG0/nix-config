{pkgs, ...}: {
  # Prevent AWS VPN from hijacking all DNS queries.
  # The AWS VPN client sets tun0 as a default DNS route, which causes
  # all queries (including local domains) to go through the VPN DNS.
  # This dispatcher script disables default-route on tun0 whenever it
  # comes up, so non-VPN queries fall through to the local DNS server.
  networking.nameservers = ["192.168.1.1"];

  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "awsvpn-dns-fix" ''
        if [ "$1" = "tun0" ] && [ "$2" = "up" ]; then
          ${pkgs.systemd}/bin/resolvectl default-route tun0 false
        fi
      '';
      type = "basic";
    }
  ];
}
