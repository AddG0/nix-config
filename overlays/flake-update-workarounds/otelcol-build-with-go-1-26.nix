# cockroachdb/swiss (an otelcol-contrib dep) links runtime internals behind a
# `go1.20 && !go1.27` build tag, so it fails to compile on the pinned Go 1.27.
# CHECK-ATTR: opentelemetry-collector-contrib
_: _final: prev: {
  opentelemetry-collector-releases = prev.opentelemetry-collector-releases.override {
    buildGoModule = prev.buildGo126Module;
  };
}
