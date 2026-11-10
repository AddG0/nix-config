# Stops t3code offering updates for what Nix pins here: the app, servers and provider CLIs.
# Drop each patch once a setting turns it off alone.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  # Not enableProviderUpdateChecks: that would also stop the model-manifest fetch.
  latestVersionGateAnchor = "options?.enableProviderUpdateChecks !== false &&";
  latestVersionGatePatch = "false &&";
  # Also holds "Update everything" for connected servers.
  updateButtonAnchor = "      <SidebarUpdatePill />\n";
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace packages/provider-core/src/server/maintenanceResolver.ts \
            --replace-fail ${escapeShellArg latestVersionGateAnchor} ${escapeShellArg latestVersionGatePatch}

          substituteInPlace apps/web/src/components/sidebar/SidebarChrome.tsx \
            --replace-fail ${escapeShellArg updateButtonAnchor} ""
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
