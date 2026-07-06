# t3code shows an "update available" banner when a provider CLI (codex,
# claude-code, opencode) is behind the latest npm release. We pin those CLIs via
# /nix/store binaryPath (home .../development/ai/t3code.nix), so the banner is
# noise with no actionable update and t3code has no setting to hide it. Forcing
# packageName to null skips the npm version fetch, so the advisory stays
# "unknown" and the banner never renders. Drop once t3code gains a toggle.
_: _final: prev: {
  t3code = prev.t3code.overrideAttrs (old: {
    postFixup =
      (old.postFixup or "")
      + ''
        substituteInPlace "$out/libexec/t3code/apps/server/dist/bin.mjs" \
          --replace-fail \
            'const packageName = maintenanceCapabilities.packageName;' \
            'const packageName = null;'
      '';
  });
}
