{inputs, ...}: _final: prev: {
  firefox-addons = import inputs.firefox-addons {
    inherit (prev) fetchurl lib stdenv;
    buildMozillaXpiAddon = (import "${inputs.firefox-addons}/../../lib/mozilla.nix" {inherit (prev) lib;}).mkBuildMozillaXpiAddon {inherit (prev) fetchurl stdenv;};
  };
}
