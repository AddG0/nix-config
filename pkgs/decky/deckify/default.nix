{
  lib,
  stdenvNoCC,
  fetchzip,
  librespot,
  openssl,
  # Host the OAuth page is served at, and so the Spotify redirect URI — it must
  # match the dashboard exactly. Null falls back to detecting the LAN address.
  advertisedHost ? null,
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

      # SAN because Chrome ignores CN and would reject the name outright.
      substituteInPlace "$out/main.py" \
        --replace-fail 'return f"{socket.gethostname()}.local"' 'return _advertised_host()' \
        --replace-fail '"-subj", f"/CN={mdns_host}",' '"-subj", f"/CN={mdns_host}", "-addext", _san_arg(mdns_host),'
      cat ${./advertised-host.py} >>"$out/main.py"
      ${lib.optionalString (advertisedHost != null) ''
        substituteInPlace "$out/main.py" \
          --replace-fail '_ADVERTISED_HOST = ""' '_ADVERTISED_HOST = "${advertisedHost}"'
      ''}
      runHook postInstall
    '';

    meta = {
      description = "Spotify Connect playback, device switching and library browsing as a Decky Loader plugin";
      homepage = "https://github.com/adv-inn/Deckify";
      license = lib.licenses.gpl3Only;
      platforms = ["x86_64-linux"];
    };
  }
