{
  lib,
  stdenvNoCC,
  fetchgit,
}:
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugin-ai-usagebar";
  version = "0-unstable-2026-09-02";

  # 24 MiB monorepo of 120 plugins.
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins.git";
    rev = "493654cce31889936decce8cc5549ec15321b7fc";
    sparseCheckout = ["ai-usagebar"];
    hash = "sha256-uTES49F0QAnKS15wMTZ7KtDoW1iWSzjePk6QMtnZJOo=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r ai-usagebar $out
    runHook postInstall
  '';

  # Upstream is untagged.
  passthru.nixUpdate.version = "branch";

  meta = {
    description = "Noctalia bar widget and panel showing AI plan usage, drawn from the ai-usagebar CLI";
    homepage = "https://github.com/noctalia-dev/community-plugins/tree/main/ai-usagebar";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
