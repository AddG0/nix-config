{inputs, ...}: _final: prev:
prev.lib.optionalAttrs prev.stdenv.isLinux {
  zen-browser = inputs.zen-browser.packages.${prev.stdenv.hostPlatform.system}.default;
}
