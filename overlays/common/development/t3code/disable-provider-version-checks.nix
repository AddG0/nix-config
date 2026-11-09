# t3code shows an "update available" banner when a provider CLI (codex,
# claude-code, opencode) is behind the latest npm release. We pin those CLIs by
# path (home .../development/ai/t3code), so the banner is noise with no
# actionable update. Gating the latest-version lookup off skips both the npm
# registry fetch and the `npm view` probe, so the advisory stays "unknown".
# Upstream's enableProviderUpdateChecks would also stop the model-manifest fetch.
#
# Drop once a setting turns off provider version checks alone.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  latestVersionGateAnchor = "options?.enableProviderUpdateChecks !== false &&";
  latestVersionGatePatch = "false &&";
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace packages/provider-core/src/server/maintenanceResolver.ts \
            --replace-fail ${escapeShellArg latestVersionGateAnchor} ${escapeShellArg latestVersionGatePatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
