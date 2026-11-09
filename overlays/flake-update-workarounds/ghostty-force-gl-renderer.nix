# GTK4's GSK GPU renderer aborts ghostty (SIGABRT) asserting inside
# gdk_dmabuf_do_download_mmap when it mmaps an NVIDIA dmabuf texture for GL
# readback; NVIDIA's driver doesn't support mmap on exported dmabufs for every
# GPU/driver combo (see NVIDIA/open-gpu-kernel-modules#748). Force the older GL
# renderer, which skips that path.
# CHECK-RUNTIME: open ghostty and let it run a few minutes of normal rendering;
# upstream is fixed when it no longer needs GSK_RENDERER=gl to avoid the abort
# in `coredumpctl list ghostty`.
_: _final: prev: {
  ghostty = prev.ghostty.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [prev.makeWrapper];
    postFixup =
      (old.postFixup or "")
      + ''
        wrapProgram $out/bin/ghostty --set GSK_RENDERER gl
      '';
  });
}
