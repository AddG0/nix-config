{pkgs, ...}: let
  # The session's LIBVA_DRIVER_NAME=nvidia hides vah264enc — that driver is
  # decode-only — silently downgrading GND to software x264enc, which stalls.
  gnome-network-displays-hwenc = pkgs.symlinkJoin {
    name = "gnome-network-displays-hwenc";
    paths = [pkgs.gnome-network-displays];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for bin in gnome-network-displays gnome-network-displays-daemon; do
        rm "$out/bin/$bin"
        makeWrapper "${pkgs.gnome-network-displays}/bin/$bin" "$out/bin/$bin" \
          --unset LIBVA_DRIVER_NAME
      done
    '';
  };
in {
  environment.systemPackages = [
    gnome-network-displays-hwenc # remote display manager
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
