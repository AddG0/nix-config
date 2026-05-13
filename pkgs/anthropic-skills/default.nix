{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "anthropic-skills";
  version = "0-unstable-2026-05-06";

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "d211d437443a7b2496a3dad9575e7dddd724c585";
    sha256 = "sha256-5NGI0gojBGoXXus8CPhIrigyWSEYJg8gnCzWYl6PsLA=";
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
