{
  lib,
  appimageTools,
  fetchurl,
  ...
}: let
  pname = "helium";
  version = "0.6.4.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    sha256 = "0e5105b85c31d908ebf5e6faba2498cccfc5debda176d90c5b976b27226dfd81";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      # Install desktop entry
      install -Dm644 ${appimageContents}/helium.desktop $out/share/applications/helium.desktop

      # Update Exec path in desktop file
      substituteInPlace $out/share/applications/helium.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'

      # Install icon (256x256)
      install -Dm644 ${appimageContents}/usr/share/icons/hicolor/256x256/apps/helium.png \
        $out/share/icons/hicolor/256x256/apps/helium.png
    '';

    meta = with lib; {
      description = "The Chromium-based web browser made for people, with love. Best privacy by default, unbiased ad-blocking, no bloat and no noise";
      longDescription = ''
        Helium is a Chromium-based web browser based on ungoogled-chromium.
        It provides the best privacy by default with unbiased ad-blocking,
        no Google bloat, and no unnecessary features.
      '';
      homepage = "https://helium.computer/";
      downloadPage = "https://github.com/imputnet/helium-linux/releases";
      changelog = "https://github.com/imputnet/helium-linux/releases/tag/${version}";
      license = licenses.gpl3Only;
      maintainers = [];
      platforms = ["x86_64-linux"];
      mainProgram = "helium";
      sourceProvenance = with sourceTypes; [binaryNativeCode];
    };
  }
