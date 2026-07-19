{
  lib,
  stdenvNoCC,
  fetchzip,
  buildFHSEnv,
  python3,
  glib,
  gobject-introspection,
  gst_all_1,
  pipewire,
  libnice,
  srtp,
  libvpx,
  openssl,
  nss,
  libva,
  mesa,
  dbus,
}: let
  # Rolling "dev" build — the only artifact upstream ships (no release zips),
  # and the only one carrying the pacman-built gstreamer stack in ./bin.
  # Re-pin when https://tzatzikiweeb.moe/Deckcord.zip is republished.
  version = "0-unstable-2026-03-22";

  src = fetchzip {
    url = "https://tzatzikiweeb.moe/Deckcord.zip";
    hash = "sha256-NXm2DziDhzf1ohEbFFKYnuDsI4r9mA7Ezv4lCahVdcY=";
    stripRoot = false;
  };

  # The voice backend (gst_webrtc.py) is spawned as a separate `/usr/bin/python`
  # that dlopen's the bundled SteamOS gstreamer libs in ./bin. NixOS has neither
  # /usr/bin/python nor the FHS base libs those .so's link against, so run it in
  # an FHS sandbox providing a Python with PyGObject plus that runtime stack.
  webrtcPython = buildFHSEnv {
    name = "deckcord-python";
    targetPkgs = _:
      [
        (python3.withPackages (ps: with ps; [pygobject3 pycairo]))
        glib
        gobject-introspection
        pipewire
        libnice
        srtp
        libvpx
        openssl
        nss
        libva
        mesa
        dbus
      ]
      ++ (with gst_all_1; [
        gstreamer
        gst-plugins-base
        gst-plugins-good
        gst-plugins-bad
        gst-plugins-ugly
        gst-libav
      ]);
    runScript = "python3";
  };
in
  stdenvNoCC.mkDerivation {
    pname = "deckcord";
    inherit version src;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r ./. "$out/"
      substituteInPlace "$out/main.py" \
        --replace-fail '"/usr/bin/python"' '"${webrtcPython}/bin/deckcord-python"'
      runHook postInstall
    '';

    passthru.nixUpdate.version = "skip";

    meta = {
      description = "Discord on the Steam Deck, packaged as a Decky Loader plugin";
      homepage = "https://github.com/marios8543/Deckcord";
      license = lib.licenses.bsd3;
      platforms = ["x86_64-linux"];
    };
  }
