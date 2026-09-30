{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "ollama-zsh-completion";
  version = "0-unstable-2026-08-24";

  src = fetchFromGitHub {
    owner = "ocodo";
    repo = "ollama_zsh_completion";
    rev = "edc7bd20a6f3ecea5aa9b651a7f20e2fd2a2f595";
    hash = "sha256-uuIkrWmZqg3pbIcxI/8OLUvMKdc9PJtmWg+2nxGDsRo=";
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
