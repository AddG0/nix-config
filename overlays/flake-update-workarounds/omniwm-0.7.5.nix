# nixpkgs pins OmniWM 0.7.1, whose focus border drops each window's measured
# corner radius on focus change and draws a 9pt default instead (OmniNull/OmniWM#781).
# home/common/optional/desktops/omniwm/settings-defaults.toml is generated from
# the same version; regenerate it when dropping this.
# CHECK-RUNTIME: drop once nixpkgs `omniwm.version` is 0.7.5 or newer.
_: _final: prev: {
  omniwm = prev.omniwm.overrideAttrs (finalAttrs: _: {
    version = "0.7.5";
    src = prev.fetchurl {
      url = "https://github.com/OmniNull/OmniWM/releases/download/v${finalAttrs.version}/OmniWM-v${finalAttrs.version}.zip";
      hash = "sha256-oV/KNBGojdBviTUyjChiY9V6RMe8wiVUd+KTA/qUzM4=";
    };
  });
}
