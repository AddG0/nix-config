{
  lib,
  appimageTools,
  fetchurl,
}: let
  pname = "wooting-bg-service";
  version = "0.5.0";

  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    url = "https://api.wooting.io/public/bg-service/download-installer?target=linux&version=${version}";
    hash = "sha256-e5NQ9rExdmvobXMEQDfrnU0ofIDOd14AEfH7SkRC6VU=";
  };

  appimageContents = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -Dm644 "${appimageContents}/usr/share/applications/Wooting Background Service.desktop" \
        $out/share/applications/${pname}.desktop
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail "Categories=" "Categories=Utility;"

      for size in 32x32 128x128 256x256@2; do
        install -Dm644 "${appimageContents}/usr/share/icons/hicolor/$size/apps/${pname}.png" \
          "$out/share/icons/hicolor/$size/apps/${pname}.png"
      done
    '';

    # skip: version is a download-URL query param and upstream's releases are private.
    passthru.nixUpdate.version = "skip";

    meta = {
      description = "Wooting Background Service - keeps a connection to Wooting keyboards open for Wootility";
      longDescription = ''
        Serves Wootility (desktop and browser) on localhost:50052 so features
        that need a live keyboard connection keep working with Wootility
        closed: Light Indicator data sources (CPU/RAM, volume, battery,
        Discord) and app-linked profile switching.
      '';
      homepage = "https://wooting.io/wootility";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      mainProgram = "wooting-bg-service";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    };
  }
