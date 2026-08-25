# neotest-gradle reads the test results directory from Gradle's legacy
# `testResultsDir` project property and never checks the answer. Gradle 9 stopped
# backing it — `properties --property testResultsDir` prints the literal string
# "null" — so every test run dies on an ENOENT for "null/test". The value survives
# on JavaPluginExtension but the `properties` task can't reach it, so the patch
# reads the full listing and falls back to `buildDir`.
#
# Upstream (weilbith/neotest-gradle) is two commits, the last of which is the rev
# nixpkgs pins — this retires only if nixpkgs repoints at a maintained fork.
# CHECK-RUNTIME: run <leader>tt in a Gradle 9 project — upstream is fixed when results appear instead of an ENOENT on "null/test".
_: _final: prev: {
  vimPlugins =
    prev.vimPlugins
    // {
      neotest-gradle = prev.vimPlugins.neotest-gradle.overrideAttrs (old: {
        patches = (old.patches or []) ++ [./neotest-gradle-results-dir.patch];
      });
    };
}
