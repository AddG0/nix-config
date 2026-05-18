{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "github-gitignore-templates";
  version = "0-unstable-2026-05-15";

  src = fetchFromGitHub {
    owner = "github";
    repo = "gitignore";
    rev = "ca6c873762f926cdc361fbbc42d8357a45145ba2";
    hash = "sha256-j1BrJQIJvajn824g9LEv0FtU3GpzxuzpJ9U/Kt35u7Q=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/gitignore
    cp -r . $out/share/gitignore/
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Collection of .gitignore templates curated by GitHub";
    homepage = "https://github.com/github/gitignore";
    license = licenses.cc0;
    platforms = platforms.all;
  };
}
