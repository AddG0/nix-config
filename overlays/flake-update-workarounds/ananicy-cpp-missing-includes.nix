# ananicy-cpp 1.2.0 relies on <cstring>/<cstdint>/<unistd.h> arriving
# transitively, which stopped happening with glibc 2.42 — clang errors on
# std::memset, std::strerror and std::int32_t. Upstream fixed the includes in
# ananicy-cpp MR!43; nixpkgs#552211 backports it but hasn't merged. Drop both
# this file and the fetchpatch once that PR lands on our pin.
# CHECK-ATTR: ananicy-cpp
_: _final: prev: {
  ananicy-cpp = prev.ananicy-cpp.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        (prev.fetchpatch {
          name = "fix-cstring-include.patch";
          url = "https://gitlab.com/ananicy-cpp/ananicy-cpp/-/merge_requests/43.diff";
          hash = "sha256-drBUVh+N3KedJttzQIIA1s+38ngK9BgZFOdpxqBWV0E=";
        })
      ];
  });
}
