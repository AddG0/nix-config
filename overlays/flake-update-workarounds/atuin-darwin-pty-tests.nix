# atuin 18.23.0's e2e suites drive real shells over ptys and time out in the darwin sandbox.
# Skipping per test only moves the failure: cargo stops at the first failing binary.
# CHECK-ATTR: atuin
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  atuin = prev.atuin.overrideAttrs {doCheck = false;};
}
