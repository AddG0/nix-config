{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "caveman";
  version = "0-unstable-2026-04-25";

  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "84cc3c14fa1e10182adaced856e003406ccd250d";
    hash = "sha256-M+NoWXxrhtbkbe/lmq7P0/KpmqOZzJjhgeUVjY+7N2k=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/caveman
    cp -r skills $out/share/caveman/
    cp -r commands $out/share/caveman/
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Ultra-compressed communication mode for AI coding agents";
    homepage = "https://github.com/JuliusBrussee/caveman";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
