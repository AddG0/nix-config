{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "noir-splash-6";
  version = "2025-12-09";

  src = fetchFromGitHub {
    owner = "L4ki";
    repo = "Breeze-Noir-Dark";
    rev = "d6accb50a43c0c4954c16638b9c5c58c24f58485";
    sha256 = "sha256-/wP0ByEcxIX+0Ngxin7gfCSR0BvHV3aqVdMwBNt+UtM=";
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
