# t3code shows an "update available" banner when a provider CLI (codex,
# claude-code, opencode) is behind the latest npm release. We pin those CLIs by
# path (home .../development/ai/t3code), so the banner is noise with no
# actionable update and t3code has no setting to hide it. Forcing packageName to
# null skips the npm version fetch, so the advisory stays "unknown" and the
# banner never renders. Drop once t3code gains a toggle.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  versionFetchAnchor = "const packageName = maintenanceCapabilities.packageName;";
  versionFetchPatch = "const packageName = null;";
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace apps/server/src/provider/providerMaintenance.ts \
            --replace-fail ${escapeShellArg versionFetchAnchor} ${escapeShellArg versionFetchPatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
