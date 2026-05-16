{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-code-skills-collection";
  version = "0.1-unstable-2026-05-14";

  src = fetchFromGitHub {
    owner = "lyndonkl";
    repo = "claude";
    rev = "f5412ae016369c97ff2910e7f98726e5763fcdd8";
    sha256 = "sha256-fnq8Lt8bcEOywM3G83krtcdwQrm3/ZqRC+FLPqLN9Uc=";
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
