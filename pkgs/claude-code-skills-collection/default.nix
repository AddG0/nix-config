{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-code-skills-collection";
  version = "0-unstable-2026-02-15";

  src = fetchFromGitHub {
    owner = "lyndonkl";
    repo = "claude";
    rev = "5433aa4ec62dc19736e21c7b95c0aaa50afc4b25";
    sha256 = "sha256-q1wpccPV2Y+pGwXKQcB3HVdsQWOW6LWnyf5djZ376TU=";
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
