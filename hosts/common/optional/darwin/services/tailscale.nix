{pkgs, ...}: {
  services.tailscale = {
    enable = true;
    package = pkgs.tailscale.overrideAttrs (_old: {
      doCheck = false; # Skip flaky tests on Darwin
    });
  };

  # Full-tunnel VPNs (0/1 + 128/1) make the default-interface bind unroutable; bind per route instead.
  # Needs overlays/flake-update-workarounds/tailscale-darwin-p2p-route-index.nix for point-to-point utuns.
  launchd.daemons.tailscaled.serviceConfig.EnvironmentVariables.TS_BIND_TO_INTERFACE_BY_ROUTE = "1";
}
