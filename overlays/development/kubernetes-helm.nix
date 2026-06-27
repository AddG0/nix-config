# helm 4.2.0 nixpkgs packaging bug on Darwin: preBuild patches test files (e.g.
# dependency_build_test.go) that were removed/renamed in helm 4.x.
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.isDarwin {
  kubernetes-helm = prev.kubernetes-helm.overrideAttrs (_old: {
    doCheck = false;
  });
}
