{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "superpowers-skills";
  version = "5.0.6-unstable-2026-03-25";

  src = fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "eafe962b18f6c5dc70fb7c8cc7e83e61f4cdde06";
    sha256 = "sha256-r/Z+UxSFQIx99HnSPoU/toWMddXDcnLsbFXpQfLfj1k=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code/skills
    cp -r skills/* $out/share/claude-code/skills/
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Superpowers - Claude Code development workflow skills";
    homepage = "https://github.com/obra/superpowers";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
