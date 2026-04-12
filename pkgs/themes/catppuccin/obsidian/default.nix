{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "catppuccin-obsidian";
  version = "2.0.3";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "obsidian";
    rev = version;
    sha256 = "sha256-9fSFj9Tzc2aN9zpG5CyDMngVcwYEppf7MF1ZPUWFyz4=";
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
