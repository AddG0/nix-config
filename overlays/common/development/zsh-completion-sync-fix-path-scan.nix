# Upstream's PATH-scan (`zstyle ':completion-sync:path' enabled true`) has four
# bugs; each patch header describes the ones it fixes. Drop when fixed upstream
# (BronzeDeer/zsh-completion-sync).
_: _final: prev: {
  zsh-completion-sync = prev.zsh-completion-sync.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ./zsh-completion-sync-add-scanned-dir-on-first-run.patch
        ./zsh-completion-sync-keep-path-order-and-rescan.patch
        ./zsh-completion-sync-dedupe-against-resolved-fpath.patch
      ];
  });
}
