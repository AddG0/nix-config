# The workspace picker lists every live worktree of the repo alongside the
# current checkout, and "New worktree" opens the ref list: pick a free branch to
# check it out, or type a name to cut one from the current checkout. Upstream
# only offered "current / new worktree / previous worktree", and a new worktree
# always got a generated branch off origin/HEAD.
#
# Settling a thread that is the last one in its worktree now offers to remove
# the worktree, which upstream only does when a thread is deleted.
#
# Drop once t3code ships a worktree picker of its own.
#
# Patched in `unwrapped`: see README.md. A `.patch` rather than
# substituteInPlace anchors — six files, ~40 hunks — and `patches` still fails
# the build on a bump that moves the code, which is the point of the anchors.
_: _final: prev: {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./patches/worktree-picker.patch];
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
