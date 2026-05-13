{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "caveman";
  version = "1.7.0-unstable-2026-05-01";

  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "ef6050c5e1848b6880ff47c32ade1a608a64f85e";
    hash = "sha256-LlyBlFsKUHKzsOXEwENoVSsZHtKENVY4vFMRf08vzoU=";
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
