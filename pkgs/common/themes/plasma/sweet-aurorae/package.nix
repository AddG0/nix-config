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
    rev = "2bed089534dd21d5da9b9c47193a85f58658e3d3";
    sha256 = "sha256-hPLgUVD9I9jcG40GmQwvA7RkSs3mq0lApOz1m/nDpL8=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/aurorae/themes/Sweet

    # Copy metacity-1 theme files for use with Aurorae
    # Aurorae can use metacity themes
    cp -r $src/metacity-1/* $out/share/aurorae/themes/Sweet/

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
