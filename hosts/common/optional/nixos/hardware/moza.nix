{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = [pkgs.boxflat];

  # Registers boxflat's 99-boxflat.rules for MOZA USB serial (vendor 346e).
  services.udev.packages = [pkgs.boxflat];

  # Out-of-tree hid-universal-pidff module for MOZA force feedback.
  boot.extraModulePackages = [config.boot.kernelPackages.universal-pidff];
}
