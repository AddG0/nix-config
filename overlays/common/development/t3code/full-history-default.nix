# When a long Claude thread's prompt cache has gone cold, t3code's composer
# shows a Compact chip that defaults on, so Enter sends `/compact` ahead of the
# message and the agent continues from a summary. This makes the chip default to
# Full: the set it keeps now holds the threads switched *to* Compact, and a send
# clears the entry so each thread falls back to Full.
#
# Drop once upstream offers a default-to-full-history setting.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  file = "apps/web/src/components/ChatView.tsx";

  readAnchor = "const keepFullHistory = fullHistoryThreadKeys.has(routeThreadKey);";
  readPatch = "const keepFullHistory = !fullHistoryThreadKeys.has(routeThreadKey);";

  noopAnchor = "if (current.has(threadKey) === keep) return current;";
  noopPatch = "if (current.has(threadKey) !== keep) return current;";

  writeAnchor = ''
    if (keep) next.add(threadKey);
          else next.delete(threadKey);'';
  writePatch = ''
    if (keep) next.delete(threadKey);
          else next.add(threadKey);'';

  resetAnchor = "setKeepFullHistory(routeThreadKey, false);";
  resetPatch = "setKeepFullHistory(routeThreadKey, true);";
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace ${file} \
            --replace-fail ${escapeShellArg readAnchor} ${escapeShellArg readPatch} \
            --replace-fail ${escapeShellArg noopAnchor} ${escapeShellArg noopPatch} \
            --replace-fail ${escapeShellArg writeAnchor} ${escapeShellArg writePatch} \
            --replace-fail ${escapeShellArg resetAnchor} ${escapeShellArg resetPatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
