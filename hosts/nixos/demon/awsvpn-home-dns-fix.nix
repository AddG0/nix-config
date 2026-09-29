{pkgs, ...}: {
  # The AWS VPN routes every DNS domain (~.) through tun0; a longer global routing domain keeps home names on the LAN resolver.
  networking.nameservers = ["10.61.20.1"];
  services.resolved.settings.Resolve.Domains = ["~addg0.com"];

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
