# Standalone package, NOT overrideAttrs on pkgs.yarn-berry: yarn-berry is a
# build-time tool for every Electron/Node build (electron -> yarn-berry_4-fetcher),
# so mutating it cache-misses electron -> r2modman/heroic/... into a from-source
# Chromium compile. As its own package it just lands on fpath.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "yarn-berry-completions";
  version = "0-unstable-2026-03-10";

  src = fetchFromGitHub {
    owner = "ursine-code";
    repo = "yarn-shell-completion";
    rev = "17bb51ffaec91fe3fbe41c20215fef3500fdcb20";
    hash = "sha256-5McAvepDEKCtOSFMgcsWnrbbaEk9Wg4KgyyAPl0CQIc=";
  };

  installPhase = ''
    runHook preInstall
    bashComp="$out/share/bash-completion/completions/yarn"
    install -Dm644 completions/yarn "$bashComp"
    install -Dm644 completions/_yarn "$out/share/zsh/site-functions/_yarn"
    # zsh completion sources its bash engine via `brew --prefix`; point it at the store.
    substituteInPlace "$out/share/zsh/site-functions/_yarn" \
      --replace-fail 'if command -v brew &>/dev/null; then' 'if true; then' \
      --replace-fail '$(brew --prefix)/etc/bash_completion.d/yarn' "$bashComp"
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Bash and zsh completion for yarn-berry (yarn 2+), generated from live `yarn help` output";
    homepage = "https://github.com/ursine-code/yarn-shell-completion";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
