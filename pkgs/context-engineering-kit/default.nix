{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "context-engineering-kit";
  version = "2.2.2-unstable-2026-03-29";

  src = fetchFromGitHub {
    owner = "NeoLabHQ";
    repo = "context-engineering-kit";
    rev = "c4da85aef8c486148c33131e736c896dfa302bf0";
    sha256 = "sha256-YGnZA4EDrcCnM8zPJphB2G0gEPhRrkt2Gec5pWRftcE=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code
    cp -r plugins $out/share/claude-code/
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Context Engineering Kit - Claude Code plugins for improving agent quality";
    homepage = "https://github.com/NeoLabHQ/context-engineering-kit";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
