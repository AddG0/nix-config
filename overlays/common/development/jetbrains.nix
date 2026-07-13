# Fix nixpkgs addPlugins on Darwin: the substitute loop only patches
# $out/<rootDir>/bin/* (inside the .app bundle) but misses $out/bin/* where the
# convenience launcher lives, leaving a disallowed reference to the unwrapped IDE.
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.isDarwin {
  jetbrains =
    prev.jetbrains
    // {
      plugins =
        prev.jetbrains.plugins
        // {
          addPlugins = ide: plugins:
            (prev.jetbrains.plugins.addPlugins ide plugins).overrideAttrs (old: {
              buildPhase =
                old.buildPhase
                + ''
                  for exe in $out/bin/*; do
                    if [ -x "$exe" ] && ( file "$exe" | grep -q 'text' ); then
                      substituteInPlace "$exe" --replace-quiet '${ide}' $out
                    fi
                  done
                '';
            });
        };
    };
}
