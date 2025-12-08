{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  webkitgtk_4_1,
  libayatana-appindicator,
  iw,
  wirelesstools,
  nettools,
}:
let
  pname = "wifiman-desktop";
  version = "1.2.8";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://desktop.wifiman.com/wifiman-desktop-${version}-amd64.deb";
    hash = "sha256-R+MbwxfnBV9VcYWeM1NM08LX1Mz9+fy4r6uZILydlks=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    webkitgtk_4_1
    libayatana-appindicator
  ];

  unpackPhase = ''
    dpkg -x $src .
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/share

    cp -r usr/lib/wifiman-desktop/* $out/lib/
    cp -r usr/share/* $out/share/

    makeWrapper usr/bin/wifiman-desktop $out/bin/wifiman-desktop \
      --prefix PATH : ${lib.makeBinPath [iw wirelesstools nettools]}

    runHook postInstall
  '';

  meta = {
    description = "WiFiMan Desktop - Network scanner and speed test by Ubiquiti";
    homepage = "https://ui.com/download/app/wifiman-desktop";
    license = lib.licenses.unfree;
    platforms = ["x86_64-linux"];
    mainProgram = "wifiman-desktop";
  };
}
