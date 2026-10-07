# The original alexzielenski/Mousecape stopped applying capes on macOS 26.1;
# this SwiftUI fork re-registers the renamed Tahoe cursor identifiers.
{
  lib,
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mousecape";
  version = "1.2.0";

  src = fetchzip {
    url = "https://github.com/sdmj76/Mousecape-swiftUI/releases/download/Swift_v${finalAttrs.version}/Mousecape_swiftUI_v${finalAttrs.version}.zip";
    hash = "sha256-fdwYmkJ7XSVVvs1w9nDS4hX/Ufw2ax8YGZT84rePl/M=";
    stripRoot = false;
  };

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications $out/bin
    cp -R Mousecape.app $out/Applications/
    ln -s $out/Applications/Mousecape.app/Contents/MacOS/mousecloak $out/bin/mousecloak
    runHook postInstall
  '';

  meta = {
    description = "macOS cursor manager with the mousecloak CLI, rewritten for macOS Tahoe";
    homepage = "https://github.com/sdmj76/Mousecape-swiftUI";
    mainProgram = "mousecloak";
    platforms = lib.platforms.darwin;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
