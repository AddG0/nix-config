# A Claude account reporting extra-usage credits gets a fourth card, which the
# stock height = 400 panel clips mid-progress-bar. Noctalia resolves a plugin
# panel's extent from the manifest with no config override, and "fill" is
# rejected for a non-floating panel, so the manifest is the only lever. 460 fits
# today's card set exactly — a fifth window would clip again.
#
# Unlike its neighbours this patches our own pkgs/noctalia-plugins, not nixpkgs,
# so it retires on a `just update-packages` rev bump, not a flake input bump.
# CHECK-RUNTIME: open the AI Usage panel — upstream is fixed when the last card renders whole at the stock height = 400.
_: _final: prev: {
  noctalia-plugins =
    prev.noctalia-plugins
    // {
      ai-usagebar = prev.noctalia-plugins.ai-usagebar.overrideAttrs (old: {
        postPatch =
          (old.postPatch or "")
          + ''
            substituteInPlace ai-usagebar/plugin.toml \
              --replace-fail "height = 400" "height = 460"
          '';
      });
    };
}
