{
  lib,
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sol";
  version = "2.1.363";

  src = fetchzip {
    url = "https://github.com/ospfranco/sol/releases/download/${finalAttrs.version}/${finalAttrs.version}.zip";
    hash = "sha256-SZsgXXsQKcgjfbslexI0kyXkA9O9pTffuHMzl+NW2qw=";
    stripRoot = false;
  };

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -R Sol.app $out/Applications/
    runHook postInstall
  '';

  meta = {
    description = "Open-source macOS app launcher";
    homepage = "https://github.com/ospfranco/sol";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
