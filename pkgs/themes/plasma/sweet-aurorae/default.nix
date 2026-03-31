{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "sweet-aurorae";
  version = "6.0-unstable-2026-03-17";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Sweet";
    rev = "33fb31cf959cdc7b5a7ce7816abcc2b55e1e1c60"; # nova branch
    sha256 = "sha256-CiG99F66FH/5XpjgbAofoFzulSrBz60k4spsBYyPuio=";
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
