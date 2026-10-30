# Everything that talks to Steam's CEF debugger hardcodes CEF's default 8080,
# so each one has to be retargeted to the port gaming/steam.nix launches with.
# Decky itself is patched in gaming/decky.nix: Jovian's overlay, applied after
# this one, supplies the jovianPackages.decky-loader its service runs.
#
# `--replace-fail` on purpose: a future release that renames or moves one of
# these URLs breaks the build rather than silently reverting to a dead port,
# which is invisible at runtime (CSS Loader simply injects nothing).
_: _final: prev: let
  port = "21379";
in {
  addg = prev.addg.overrideScope (_: aprev: {
    decky = aprev.decky.overrideScope (_: nprev: {
      # Health-checks the debugger and injects nothing at all while it fails.
      css-loader = nprev.css-loader.overrideAttrs (o: {
        postInstall =
          (o.postInstall or "")
          + ''
            substituteInPlace "$out/css_browserhook.py" \
              --replace-fail "http://127.0.0.1:8080" "http://127.0.0.1:${port}"
          '';
      });
    });
  });
}
