{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "context-engineering-kit";
  version = "0-unstable-2026-04-22";

  src = fetchFromGitHub {
    owner = "NeoLabHQ";
    repo = "context-engineering-kit";
    rev = "dedca19ced62758f68a8a34cd2329ec065ecce6a";
    sha256 = "sha256-X/BKLcf+Y+arYvu6ezvGg+KbynJUm7GnBkXTRSR34VA=";
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
