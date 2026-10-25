# Pin elephant to walker's own elephant input, patched so the
# desktopapplications provider never shows a matched Exec verbatim — on Nix
# that's a /nix/store/<hash>-... path long enough to win the fuzzy match and
# leak into the launcher's subtitle. Search still covers Exec; only the
# display fallback changes (falls back to GenericName instead).
{inputs, ...}: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (let
  version = prev.lib.trim (builtins.readFile "${inputs.walker.inputs.elephant}/cmd/elephant/version.txt");
  elephant = inputs.walker.inputs.elephant.packages.${prev.stdenv.hostPlatform.system};
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
  elephant-with-providers = prev.stdenv.mkDerivation {
    pname = "elephant-with-providers";
    inherit version;
    dontUnpack = true;
    nativeBuildInputs = [prev.makeWrapper];
    installPhase = ''
      mkdir -p $out/bin $out/lib/elephant
      cp ${elephant.elephant}/bin/elephant $out/bin/
      cp -r ${providers}/lib/elephant/providers $out/lib/elephant/
    '';
    postFixup = ''
      wrapProgram $out/bin/elephant \
        --prefix PATH : ${prev.lib.makeBinPath [prev.wl-clipboard prev.libqalculate prev.imagemagick prev.bluez]}
    '';
  };
})
