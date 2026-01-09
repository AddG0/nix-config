{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-code-skills-collection";
  version = "unstable-2025-01-08";

  src = fetchFromGitHub {
    owner = "lyndonkl";
    repo = "claude";
    rev = "8ad8952e280809bdb120330715e6139d07ac91a2";
    sha256 = "08hsd5ivf68d34p1y25kg91wahzah2lza6y56vximmj92dbs4aj1";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code/plugins/claude-code-skills-collection
    cp -r . $out/share/claude-code/plugins/claude-code-skills-collection/
    runHook postInstall
  '';

  meta = with lib; {
    description = "74 production-ready skills for Claude Code across strategic thinking, product development, research, and specialized domains";
    homepage = "https://github.com/lyndonkl/claude";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
