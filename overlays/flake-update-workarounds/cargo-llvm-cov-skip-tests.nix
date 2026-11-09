# cargo-llvm-cov 0.9.0's tests merge rustc's raw profiles (format v11) with
# llvm-22's llvm-profdata, which only reads v10, so 14 tests fail.
# CHECK-ATTR: cargo-llvm-cov
_: _final: prev: {
  cargo-llvm-cov = prev.cargo-llvm-cov.overrideAttrs {doCheck = false;};
}
