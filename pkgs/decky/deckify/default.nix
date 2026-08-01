{
  lib,
  stdenvNoCC,
  fetchzip,
  librespot,
  openssl,
}: let
  version = "0.1.4";
in
  stdenvNoCC.mkDerivation {
    pname = "deckify";
    inherit version;

    src = fetchzip {
      url = "https://github.com/adv-inn/Deckify/releases/download/v${version}/Deckify.tar.gz";
      hash = "sha256-FGsqlue4khAi9tF9lQyicEAEeGhknpbaLCArapBWG+Q=";
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r ./. "$out/"
      # Bundled librespot is the same 0.8.0, but linked against /usr libpulse+libssl.
      rm -rf "$out/bin"
      substituteInPlace "$out/main.py" \
        --replace-fail 'os.path.join(decky.DECKY_PLUGIN_DIR, "bin", "librespot")' '"${lib.getExe librespot}"' \
        --replace-fail '"openssl", "req"' '"${lib.getExe' openssl "openssl"}", "req"'
      runHook postInstall
    '';

    meta = {
      description = "Spotify Connect playback, device switching and library browsing as a Decky Loader plugin";
      homepage = "https://github.com/adv-inn/Deckify";
      license = lib.licenses.gpl3Only;
      platforms = ["x86_64-linux"];
    };
  }
