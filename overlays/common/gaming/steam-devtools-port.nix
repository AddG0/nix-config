# Everything that talks to Steam's CEF debugger hardcodes CEF's default 8080,
# so each one has to be retargeted to the port gaming/steam.nix launches with.
#
# `--replace-fail` on purpose: a future release that renames or moves one of
# these URLs breaks the build rather than silently reverting to a dead port,
# which is invisible at runtime (CSS Loader simply injects nothing).
_: _final: prev: let
  port = "21379";
in {
  decky-loader = prev.decky-loader.overrideAttrs (o: {
    postFixup =
      (o.postFixup or "")
      + ''
        for site in $out/lib/python*/site-packages/decky_loader; do
          substituteInPlace "$site/injector.py" \
            --replace-fail "http://localhost:8080" "http://localhost:${port}"
          substituteInPlace "$site/localplatform/localplatformlinux.py" \
            --replace-fail "-iTCP:8080" "-iTCP:${port}"
        done
        # drop stale bytecode so the edits take effect at runtime
        find "$out" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
      '';
  });

  decky =
    prev.decky
    // {
      # Health-checks the debugger and injects nothing at all while it fails.
      css-loader = prev.decky.css-loader.overrideAttrs (o: {
        postInstall =
          (o.postInstall or "")
          + ''
            substituteInPlace "$out/css_browserhook.py" \
              --replace-fail "http://127.0.0.1:8080" "http://127.0.0.1:${port}"
          '';
      });
    };
}
