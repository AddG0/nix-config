{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "catppuccin-yazi";
  version = "0-unstable-2026-05-14";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "yazi";
    rev = "41f24ed142e34109a9a65a5dfe58c1b4eb6d2fd9";
    hash = "sha256-Og33IGS9pTim6LEH33CO102wpGnPomiperFbqfgrJjw=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Soothing pastel theme for Yazi";
    homepage = "https://github.com/catppuccin/yazi";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
