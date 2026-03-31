{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "anthropic-skills";
  version = "0-unstable-2026-03-25";

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "98669c11ca63e9c81c11501e1437e5c47b556621";
    sha256 = "sha256-w//9LB1OVG9jlllY+VDse7Js0dn5x6Ys2vPuQACKsTM=";
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
