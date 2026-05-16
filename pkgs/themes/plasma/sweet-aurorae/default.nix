{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "sweet-aurorae";
  version = "2.0-unstable-2026-05-07";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Sweet";
    rev = "77a4c3c9dc285bd0efa5ebd59d3372de91c3f274"; # nova branch
    sha256 = "sha256-zw3DeLjj7bc7t21C394ijf8qxroNkiMU+BbhDetnRKw=";
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
