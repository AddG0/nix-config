{
  lib,
  stdenvNoCC,
  fetchzip,
  librespot,
  openssl,
  pulseaudio,
}: let
  version = "0.2.1";
  # libmdns stays the default for hosts without avahi.
  librespotWithAvahi = librespot.override {withAvahi = true;};
in
  stdenvNoCC.mkDerivation {
    pname = "deckify";
    inherit version;

    src = fetchzip {
      url = "https://github.com/adv-inn/Deckify/releases/download/v${version}/Deckify.tar.gz";
      hash = "sha256-aVGIwThlbZyqMbABKuT3ERNES+at54J3ELFMaS16nc4=";
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
        --replace-fail 'os.path.join(decky.DECKY_PLUGIN_DIR, "bin", "librespot")' '"${lib.getExe librespotWithAvahi}"' \
        --replace-fail '"openssl", "req"' '"${lib.getExe' openssl "openssl"}", "req"'

      # SAN because Chrome ignores CN and would reject the name outright.
      substituteInPlace "$out/main.py" \
        --replace-fail 'return f"{socket.gethostname()}.local"' 'return _advertised_host()' \
        --replace-fail '"-subj", f"/CN={mdns_host}",' '"-subj", f"/CN={mdns_host}", "-addext", _san_arg(mdns_host),'
      cat ${./advertised-host.py} >>"$out/main.py"

      # A modal closes with B. The browser-opening APIs — OpenInSystemBrowser,
      # NavigateToExternalWeb — leave nothing dismissable over a running game.
      substituteInPlace "$out/dist/index.js" \
        --replace-fail 'DFL.Navigation.NavigateToExternalWeb(res.url);' 'DFL.showModal(window.SP_REACT.createElement(DFL.ModalRoot, null, window.SP_REACT.createElement("iframe", { src: res.url, style: { width: "100%", height: "70vh", border: "none" } })));'
      # Upstream's deck user is uid 1000; the env pins discovery's port, and its backend to avahi so libmdns can't rename the host.
      substituteInPlace "$out/main.py" \
        --replace-fail 'PULSE_SERVER = "unix:/run/user/1000/pulse/native"' 'PULSE_SERVER = f"unix:/run/user/{os.getuid()}/pulse/native"' \
        --replace-fail '"--system-cache", CACHE_DIR,' '"--system-cache", CACHE_DIR, *(["--zeroconf-port", os.environ["DECKIFY_ZEROCONF_PORT"]] if os.environ.get("DECKIFY_ZEROCONF_PORT") else []), *(["--zeroconf-backend", os.environ["DECKIFY_ZEROCONF_BACKEND"]] if os.environ.get("DECKIFY_ZEROCONF_BACKEND") else []),'
      # DECKIFY_SPOTIFY_CLIENT_ID (public under PKCE) skips the client-ID form; logout clears the stored ID, so every read falls back to it.
      substituteInPlace "$out/main.py" \
        --replace-fail 'self._settings.get("spotify_client_id", "").strip()' '(self._settings.get("spotify_client_id", "").strip() or _SPOTIFY_CLIENT_ID)' \
        --replace-fail '    async def _send_landing_page(self, writer: asyncio.StreamWriter):' '    async def _send_landing_page(self, writer: asyncio.StreamWriter):
              if _SPOTIFY_CLIENT_ID:
                  return await self._redirect_to_spotify(_SPOTIFY_CLIENT_ID, writer)'
      echo '_SPOTIFY_CLIENT_ID = os.environ.get("DECKIFY_SPOTIFY_CLIENT_ID", "")' >>"$out/main.py"
      cat ${./rate-limit.py} >>"$out/main.py"
      # Volume boost for librespot's sink input; plugins run with the loader's PATH, which has no pactl.
      substituteInPlace "$out/main.py" \
        --replace-fail '["pactl", "list", "sink-inputs"]' '["${lib.getExe' pulseaudio "pactl"}", "list", "sink-inputs"]' \
        --replace-fail '["pactl", "set-sink-input-volume",' '["${lib.getExe' pulseaudio "pactl"}", "set-sink-input-volume",'
      runHook postInstall
    '';

    meta = {
      description = "Spotify Connect playback, device switching and library browsing as a Decky Loader plugin";
      homepage = "https://github.com/adv-inn/Deckify";
      license = lib.licenses.gpl3Only;
      platforms = ["x86_64-linux"];
    };
  }
