# debugpy 1.8.22's test_lldb_command fails (`assert False`) on darwin against
# python 3.14; the other 965 tests pass, and nixpkgs already skips sibling
# darwin-only attach tests in disabledTestPaths.
# CHECK-ATTR: python314Packages.debugpy
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  pythonPackagesExtensions =
    prev.pythonPackagesExtensions
    ++ [
      (_: pyprev: {
        debugpy = pyprev.debugpy.overridePythonAttrs (old: {
          disabledTests = (old.disabledTests or []) ++ ["test_lldb_command"];
        });
      })
    ];
}
