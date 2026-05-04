{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "ollama-zsh-completion";
  version = "0-unstable-2026-02-11";

  src = fetchFromGitHub {
    owner = "ocodo";
    repo = "ollama_zsh_completion";
    rev = "ff683469b770c59f9b150878baf7846540fefd9c";
    hash = "sha256-TaNBTREO/YrvQ2v6Yf/EP8nR40zr1M4BT1cCTPaGuJE=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 _ollama $out/share/zsh/site-functions/_ollama
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Zsh tab completion for the ollama CLI, with dynamic local and remote model name completion";
    homepage = "https://github.com/ocodo/ollama_zsh_completion";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
