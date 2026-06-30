# zsh-completion-sync 0.4.0's PATH-scan (`zstyle ':completion-sync:path' enabled
# true`) is broken on a shell's first run: the init branch of
# _completion_sync:path_hook adds `$p_path` (undefined there) instead of `$elem`,
# so a fresh `nix shell` gets no completion dir added to fpath. Drop once fixed
# upstream (BronzeDeer/zsh-completion-sync).
_: _final: prev: {
  zsh-completion-sync = prev.zsh-completion-sync.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./zsh-completion-sync-path-firstrun.patch];
  });
}
