# Upstream's PATH-scan (`zstyle ':completion-sync:path' enabled true`) has four
# bugs; each patch header describes the ones it fixes. Drop when fixed upstream
# (BronzeDeer/zsh-completion-sync).
_: _final: prev: {
  zsh-completion-sync = prev.zsh-completion-sync.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ./zsh-completion-sync-path-firstrun.patch
        ./zsh-completion-sync-path-order.patch
        ./zsh-completion-sync-path-resolved-dupes.patch
      ];
  });
}
