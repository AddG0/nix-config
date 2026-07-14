# nixpkgs' opentelemetry-instrumentation-urllib3 0.64b0 still lists httpretty/
# respx as test deps, but upstream's tests now import mocket — pytest collection
# fails with ModuleNotFoundError. Drop once nixpkgs adds mocket to its check inputs.
# CHECK-ATTR: python3Packages.opentelemetry-instrumentation-urllib3
_: _final: prev: {
  pythonPackagesExtensions =
    prev.pythonPackagesExtensions
    ++ [
      (_pyfinal: pyprev: {
        opentelemetry-instrumentation-urllib3 = pyprev.opentelemetry-instrumentation-urllib3.overridePythonAttrs (old: {
          nativeCheckInputs = (old.nativeCheckInputs or []) ++ [pyprev.mocket];
        });
      })
    ];
}
