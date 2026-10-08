# tailscaled on macOS binds every socket to an interface. Under a full-tunnel
# OpenVPN (0/1 + 128/1 via a point-to-point utun), binding to the default
# interface (en7) is unroutable — `ping -b en7` gets "No route to host" — so
# tailscaled sits offline in a rebind loop. TS_BIND_TO_INTERFACE_BY_ROUTE should
# pick the utun instead, but interfaceIndexFor follows the gateway chain
# (192.200.0.104 -> 10.61.70.1 -> 10.61.70.2) only one hop, never reaches a link
# address, and falls back to en7. The kernel's RTM_GET reply already carries the
# right index in rtm_index (24 = utun5); the patch falls back to it.
# Still present on tailscale main as of 2026-10-08.
# CHECK-RUNTIME: with the work VPN up and this overlay removed, `tailscale status` lists peers instead of "fetch control key ... no route to host".
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  tailscale = prev.tailscale.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./tailscale-darwin-p2p-route-index.patch];
  });
}
