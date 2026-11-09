# nixpkgs' cargoSetupHook now forces system aws-lc, zstd and jemalloc, which
# codex's buildInputs don't provide; keep its vendored builds.
# CHECK-ATTR: codex
_: _final: prev: {
  codex = prev.codex.overrideAttrs {dontCargoUseSystemLibs = true;};
}
