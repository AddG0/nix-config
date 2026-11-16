# Settings → Secrets, and the picker that points a secret setting at a secret
# provider, are compiled out unless the web build sees T3CODE_FEATURE_SECRETS.
# The server side ships enabled; only the UI is gated. Without them no hub key
# can name a provider, so command-provider.nix has no way in.
#
# Drop once upstream turns the secrets UI on by default.
_: _final: prev: {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      env = (old.env or {}) // {T3CODE_FEATURE_SECRETS = "1";};
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
