# Lens: disable GPU to fix invisible window on NVIDIA + Wayland (Electron bug).
_: _final: prev: {
  lens = prev.lens.overrideAttrs (oldAttrs:
    prev.lib.optionalAttrs prev.stdenv.isLinux {
      buildCommand =
        (oldAttrs.buildCommand or "")
        + ''
          substituteInPlace $out/bin/lens-desktop \
            --replace-fail '"$@"' '--disable-gpu "$@"'
        '';
    });
}
