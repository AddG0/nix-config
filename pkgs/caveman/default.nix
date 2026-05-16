{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "caveman";
  version = "0-unstable-2026-05-12";

  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "63a91ecadbf4c4719a4602a5abb00883f9966034";
    hash = "sha256-Jlfas2MPoQx3pOw+yKCta8kYlOEY27SP5NXJtSL+GGI=";
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
