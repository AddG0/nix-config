{pkgs, ...}: let
  # No dmabuf-path patch: vapostproc leaves nothing able to rescale, so
  # pipewiresrc runs out of formats and the stream dies with not-negotiated (-4).
  gnd = pkgs.gnome-network-displays.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ./gnd-keepalive-quirk.patch
        ./gnd-audio-fix.patch
        ./gnd-quality.patch
        ./gnd-latency.patch
        ./gnd-gtk-thread.patch
        ./gnd-encoder-output.patch
        ./gnd-resolution-negotiation.patch
      ];
  });

  # LIBVA_DRIVER_NAME=nvidia is decode-only, so vah264enc never registers and GND
  # silently falls back to software x264enc.
  gnome-network-displays-hwenc = pkgs.symlinkJoin {
    name = "gnome-network-displays-hwenc";
    paths = [gnd];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for bin in gnome-network-displays gnome-network-displays-daemon; do
        rm "$out/bin/$bin"
        makeWrapper "${gnd}/bin/$bin" "$out/bin/$bin" \
          --unset LIBVA_DRIVER_NAME \
          --set-default GND_FALLBACK_RESOLUTION "1920x1080@60"
      done
    '';
  };
in {
  # Wi-Fi Direct discovery needs NetworkManager to ingest wpa_supplicant's P2P
  # peers; stock 1.58.0 drops them. See the patch header for the trace.
  networking.networkmanager.package = pkgs.networkmanager.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./nm-p2p-peer-poll.patch];
  });

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

  # nixpkgs restarts wpa_supplicant on any wlan add/remove, meaning for hotplugged
  # hardware -- but group formation creates one, so it kills the group mid-setup.
  # RUN= (not +=) resets the list, and this file sorts after the 99-local.rules
  # that extraRules lands in.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "wifi-p2p-keep-supplicant-rules";
      destination = "/etc/udev/rules.d/99-zz-wifi-p2p-keep-supplicant.rules";
      # udev rejects RUN="" as an empty value, hence a no-op rather than nothing.
      text = ''
        ACTION=="add|remove", SUBSYSTEM=="net", ENV{DEVTYPE}=="wlan", KERNEL=="p2p-*", RUN="${pkgs.coreutils}/bin/true"
      '';
    })
  ];

  # MICE sinks (LG webOS) reach RTSP over the LAN, not the P2P group interface, so
  # 7236 must be open there -- exposing an unauthenticated RTSP server while casting.
  networking.firewall = {
    trustedInterfaces = ["p2p-wl+"];
    allowedTCPPorts = [7236];
  };
}
