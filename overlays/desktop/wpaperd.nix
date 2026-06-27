# wpaperd 1.3.0 — nixpkgs still ships 1.2.2, missing the `wpaperctl set <file>
# <output>` subcommand the wallpaper-picker needs. cargoHash on a
# `finalAttrs:`-style buildRustPackage doesn't propagate via overrideAttrs;
# replace cargoDeps directly instead. Drop once nixpkgs catches up.
_: _final: prev: {
  wpaperd = prev.wpaperd.overrideAttrs (_old: rec {
    version = "1.3.0";
    src = prev.fetchFromGitHub {
      owner = "danyspin97";
      repo = "wpaperd";
      tag = version;
      hash = "sha256-gKO2GDR21LPx+09YUnV/wMs1uVBRDHkbY6GonTmTPPA=";
    };
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      inherit src;
      name = "wpaperd-${version}-vendor";
      hash = "sha256-dfmezhRdnKx53y9ETx2nJrILz/zgu07RuqqmGdRyhdY=";
    };
  });
}
