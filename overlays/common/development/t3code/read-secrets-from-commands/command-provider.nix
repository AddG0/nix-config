# A `command` secret provider: a reference such as `ai-proxy token` is split on
# whitespace and run without a shell, and its trimmed output is the secret. Its
# definition opts out of the resolver's cache, which otherwise holds every value
# for the server's life, so a usage hub signs in with a fresh short-lived token
# on every refresh. Settings → Secrets offers the kind with a timeout field.
#
# Drop once t3code ships a command provider of its own (offered upstream).
#
# Patched in `unwrapped`: see ../README.md. A `.patch` rather than anchors: a new
# workspace package, its lockfile entry and 18 other files.
_: _final: prev: {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./command-provider.patch];
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
