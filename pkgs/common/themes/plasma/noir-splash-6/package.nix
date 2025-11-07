{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "noir-splash-6";
  version = "2025-11-04";

  src = fetchFromGitHub {
    owner = "L4ki";
    repo = "Breeze-Noir-Dark";
    rev = "d2e84473128eedbfa2a9697dfbf4b252b84a20a6";
    sha256 = "sha256-fKxOEjLQoB/NKMXty+hGbFbzF/OhrhmFJoIbgvKbhew=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/plasma/look-and-feel
    cp -r Noir-Splash-6 $out/share/plasma/look-and-feel/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Noir Splash Screen for Plasma 6";
    homepage = "https://github.com/L4ki/Breeze-Noir-Dark";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
