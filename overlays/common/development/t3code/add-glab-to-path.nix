# Every MR feature shells out to `glab`, but nixpkgs leaves `enableGitLab` off,
# so it reaches t3code only while the user's own PATH happens to carry it — and
# the service inherits whatever PATH systemd started it with. gh, git and codex
# are on by default; this puts glab beside them in the wrapper's prefix.
_: _final: prev: {
  t3code = prev.t3code.override {
    enableGitLab = true;
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
