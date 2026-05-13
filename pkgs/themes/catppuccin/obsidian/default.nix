{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "catppuccin-obsidian";
  version = "2.0.4";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "obsidian";
    rev = "v${version}";
    hash = "sha256-fbPkZXlk+TTcVwSrt6ljpmvRL+hxB74NIEygl4ICm2U=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp manifest.json theme.css "$out/"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Soothing pastel theme for Obsidian";
    homepage = "https://github.com/catppuccin/obsidian";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
