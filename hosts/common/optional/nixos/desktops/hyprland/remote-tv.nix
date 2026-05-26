{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gnome-network-displays # remote display manager
  ];

  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
      userServices = true;
    };
  };

  # Wi-Fi P2P group interfaces NetworkManager creates per cast session.
  networking.firewall.trustedInterfaces = ["p2p-wl+"];
  networking.firewall.allowedTCPPorts = [7236 7250];
  networking.firewall.allowedUDPPorts = [7236 5353];
}
