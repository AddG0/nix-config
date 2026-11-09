# After the sixth sent prompt, t3code asks once per session for a GitHub star
# until dismissed, and the dismissal lives in each client's localStorage. Dropping
# the composer's call stops it on every client this server serves.
#
# Drop once upstream offers a setting to turn the star prompt off.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  starPromptAnchor = "void recordPromptSent(environmentId);";
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace apps/web/src/components/chat/useComposerSend.ts \
            --replace-fail ${escapeShellArg starPromptAnchor} ""
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
