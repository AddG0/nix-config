# Pin elephant to walker's own elephant input, patched so the
# desktopapplications provider never shows a matched Exec verbatim — on Nix
# that's a /nix/store/<hash>-... path long enough to win the fuzzy match and
# leak into the launcher's subtitle. Search still covers Exec; only the
# display fallback changes (falls back to GenericName instead).
{inputs, ...}: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (let
  system = prev.stdenv.hostPlatform.system;
  elephant = inputs.walker.inputs.elephant.packages.${system};
  providers = elephant.elephant-providers.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace internal/providers/desktopapplications/query.go \
          --replace-fail 'if ok && match != v.Name {' 'if ok && match != v.Name && match != v.Exec {' \
          --replace-fail 'if ok && match != a.Name {' 'if ok && match != a.Name && match != a.Exec {'
      '';
  });
in {
  elephant-with-providers = elephant.elephant-with-providers.overrideAttrs (_old: {
    installPhase = ''
      mkdir -p $out/bin $out/lib/elephant
      cp ${elephant.elephant}/bin/elephant $out/bin/
      cp -r ${providers}/lib/elephant/providers $out/lib/elephant/
    '';
  });
})
