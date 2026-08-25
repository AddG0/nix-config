{
  lib,
  stdenvNoCC,
  fetchgit,
}:
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugin-ai-usagebar";
  version = "1.1.0-unstable-2026-08-25";

  # 24 MiB monorepo of 120 plugins.
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins.git";
    rev = "81c9c71983f20058912129fe46434b7dbe8cf061";
    sparseCheckout = ["ai-usagebar"];
    hash = "sha256-mkalOzTgydnspoa6Vi3fCtBatV19Y3VMkiTbxYq31fA=";
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
