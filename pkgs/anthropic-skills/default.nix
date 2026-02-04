{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "anthropic-skills";
  version = "unstable-2025-02-04";

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "a5bcdd7e58cdff48566bf876f0a72a2008dcefbc";
    sha256 = "1kfbppbw7g3xpmlmf9n991nps4rwli3a81a2vz1bdg3mdwn0vl7j";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code/plugins/anthropic-skills
    cp -r . $out/share/claude-code/plugins/anthropic-skills/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Official Anthropic skills including skill-creator, mcp-builder, web-artifacts-builder, and more";
    homepage = "https://github.com/anthropics/skills";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
