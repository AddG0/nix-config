{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-code-plugins";
  version = "unstable-2025-01-08";

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-code";
    rev = "f34e2535b4fcf5fcc6cb0b566111c588b04873ee";
    sha256 = "1h4kvarzlslprm5csg81l3rkrd43mnfv22pbck514r3flarmxk33";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code
    cp -r plugins $out/share/claude-code/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Official Claude Code plugins from Anthropic";
    homepage = "https://github.com/anthropics/claude-code/tree/main/plugins";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
