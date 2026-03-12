{pkgs, ...}: {
  services.tailscale = {
    enable = true;
    package = pkgs.tailscale.overrideAttrs (_old: {
      doCheck = false; # Skip flaky tests on Darwin
    });
  };
}
