{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "superpowers-skills";
  version = "unstable-2025-01-04";

  src = fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "b9e16498b9b6b06defa34cf0d6d345cd2c13ad31";
    sha256 = "0wnd4icn97ig6vi97k159f8jkanrazha47pm4cbkrx20mqqf5xnk";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code/skills
    cp -r skills/* $out/share/claude-code/skills/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Superpowers - Claude Code development workflow skills";
    homepage = "https://github.com/obra/superpowers";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
