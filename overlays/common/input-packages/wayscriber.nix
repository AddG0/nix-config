# Base pkgs.wayscriber; the flake-update-workarounds overlay layers a test-skip on top.
{inputs, ...}: _final: prev:
prev.lib.optionalAttrs prev.stdenv.isLinux {
  wayscriber = inputs.wayscriber.packages.${prev.stdenv.hostPlatform.system}.default;
}
