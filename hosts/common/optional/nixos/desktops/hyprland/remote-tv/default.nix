{pkgs, ...}: let
  gnd = pkgs.gnome-network-displays.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ./gnd-cap-capture-fps.patch
        ./gnd-keepalive-quirk.patch
        ./gnd-prefer-video-only.patch
      ];
  });

  # The session sets LIBVA_DRIVER_NAME=nvidia, which is decode-only: vah264enc
  # never registers and GND silently falls back to software x264enc.
  gnome-network-displays-hwenc = pkgs.symlinkJoin {
    name = "gnome-network-displays-hwenc";
    paths = [gnd];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for bin in gnome-network-displays gnome-network-displays-daemon; do
        rm "$out/bin/$bin"
        makeWrapper "${gnd}/bin/$bin" "$out/bin/$bin" \
          --unset LIBVA_DRIVER_NAME
      done
    '';
  };
in {
  environment.systemPackages = [
    gnome-network-displays-hwenc
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
