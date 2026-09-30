{
  lib,
  stdenvNoCC,
  fetchgit,
}:
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugin-ai-usagebar";
  version = "0-unstable-2026-09-20";

  # 24 MiB monorepo of 120 plugins.
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins.git";
    rev = "f6350fe5542d414bbbe0bcca2bacbe9b59502667";
    sparseCheckout = ["ai-usagebar"];
    hash = "sha256-iCMPf51xWOAaVLfbxJX0az8mdzhSnfCKN4mqih5rSsE=";
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
