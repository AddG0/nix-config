{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "sweet-aurorae";
  version = "6.0-unstable-2026-04-22";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Sweet";
    rev = "008d3096002ca5089e3743b8d1232e53116e1214"; # nova branch
    sha256 = "sha256-rjngoodsnTLVJ2M3r96YGje1kkIKCTiLAJrSNgj+oAo=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/aurorae/themes

    # Copy KDE Aurorae themes from the nova branch
    # The nova branch contains proper Aurorae SVG themes
    cp -r $src/kde/aurorae/* $out/share/aurorae/themes/

    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Sweet window decoration theme for KDE/Aurorae";
    homepage = "https://github.com/EliverLara/Sweet";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
