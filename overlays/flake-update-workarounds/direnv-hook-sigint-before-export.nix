# Ctrl-C during a direnv load restarts it every prompt: since 2.38.0 the zsh/bash hook
# ignores SIGINT only after `direnv export`, so the shell drops the export's watches.
# Port of github.com/direnv/direnv/pull/1655 (issue #1653) to 2.38.2.
# CHECK-RUNTIME: upstream is fixed when `direnv hook zsh` sets `trap -- '' SIGINT` before `direnv export zsh`.
_: _final: prev: {
  direnv = prev.direnv.overrideAttrs (old: {
    # nixvim's own nixpkgs pin can still be on 2.37, which predates the bug.
    patches = (old.patches or []) ++ prev.lib.optional (prev.lib.versionAtLeast old.version "2.38.0") ./direnv-hook-sigint-before-export.patch;
  });
}
