{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "context-engineering-kit";
  version = "unstable-2025-01-04";

  src = fetchFromGitHub {
    owner = "NeoLabHQ";
    repo = "context-engineering-kit";
    rev = "992b0f6bd3ecbd2e650f6605991b798a4224a97c";
    sha256 = "1kp19344b80p975hvn5ama3nq0izw7qic5p3zzfmv8ihmmlwx6vd";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code
    cp -r plugins $out/share/claude-code/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Context Engineering Kit - Claude Code plugins for improving agent quality";
    homepage = "https://github.com/NeoLabHQ/context-engineering-kit";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
