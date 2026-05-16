{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "anthropic-skills";
  version = "0-unstable-2026-05-09";

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "f458cee31a7577a47ba0c9a101976fa599385174";
    sha256 = "sha256-jKNYFom6R+Qw7LQ8vFPBe51JpqIP0tTSY8LM4aPlnT4=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code/plugins/anthropic-skills
    cp -r . $out/share/claude-code/plugins/anthropic-skills/
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Official Anthropic skills including skill-creator, mcp-builder, web-artifacts-builder, and more";
    homepage = "https://github.com/anthropics/skills";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
