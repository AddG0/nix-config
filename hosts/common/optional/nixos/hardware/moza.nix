{pkgs, ...}: {
  environment.systemPackages = [pkgs.boxflat];

  # Registers boxflat's 99-boxflat.rules for MOZA USB serial (vendor 346e).
  services.udev.packages = [pkgs.boxflat];
}
