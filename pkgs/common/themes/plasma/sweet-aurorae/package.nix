{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "sweet-aurorae";
  version = "2024-11-08";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Sweet";
    rev = "f865a47ed41a870d278fcd47fdb0300fdeaa0c01"; # nova branch
    sha256 = "sha256-ohiZkwY3ii2JSxZFM2vTSNovar4QxQjDh/tO41Rm138=";
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

  meta = with lib; {
    description = "Sweet window decoration theme for KDE/Aurorae";
    homepage = "https://github.com/EliverLara/Sweet";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
