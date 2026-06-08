{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "sweet-aurorae";
  version = "6.0-unstable-2026-05-07";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Sweet";
    rev = "fa5229183093c078bebbc1b405d78909ffa18bb4"; # dark-plasma-6 branch
    sha256 = "sha256-rhcSnvNbzjpZliyL3SaZjnjmLy1nMbohGcOrSZZ9B1c=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/aurorae/themes

    # Copy KDE Aurorae themes from the dark-plasma-6 branch
    # (master/nova dropped the kde/aurorae SVG themes)
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
