{pkgs, ...}: {
  services.tailscale = {
    enable = true;
    package = pkgs.tailscale.overrideAttrs (old: {
      doCheck = false; # Skip flaky tests on Darwin
    });
  };
}
