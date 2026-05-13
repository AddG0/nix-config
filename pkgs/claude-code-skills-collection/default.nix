{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-code-skills-collection";
  version = "0.1-unstable-2026-04-25";

  src = fetchFromGitHub {
    owner = "lyndonkl";
    repo = "claude";
    rev = "cb8da039d2ecda0b4ebc74af41d2de64b8a3be9d";
    sha256 = "sha256-B3orwkLikwhPVslyhBGEiUflkiHUhQ/reBmkQIUc4Y8=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code/plugins/claude-code-skills-collection
    cp -r . $out/share/claude-code/plugins/claude-code-skills-collection/
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "74 production-ready skills for Claude Code across strategic thinking, product development, research, and specialized domains";
    homepage = "https://github.com/lyndonkl/claude";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
