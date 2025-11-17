# Based on this https://github.com/nix-community/nur-combined/blob/main/repos/hexadecimalDinosaur/pkgs/jetbrains-fleet/default.nix
# Just removed a few things that are not needed
{
  lib,
  pkgs,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,

  fontconfig,
  xorg,
  libGL,
  alsa-lib,
  wayland,
  imagemagick,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "jetbrains-fleet";
  version = "1.48.261";

  src = let
    sources = {
      x86_64-linux = {
        url = "https://download-cdn.jetbrains.com/fleet/installers/linux_x64/Fleet-${finalAttrs.version}.tar.gz";
        hash = "sha256-rDcc8v43vEw0ayOD+awMYWI19kuTcssIi03r1UJeC4M=";
      };
      aarch64-linux = {
        url = "https://download-cdn.jetbrains.com/fleet/installers/linux_aarch64/Fleet-${finalAttrs.version}-aarch64.tar.gz";
        hash = "sha256-Spx/K7XqOy56aYNsemlJ4iJjPb1RIYhxHvftcZwPT9U=";
      };
    };
  in fetchzip {
    inherit (sources.${stdenv.hostPlatform.system}) url hash;
    stripRoot = true;
  };

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  buildInputs = [
    pkgs.jetbrains.jdk
    fontconfig
    xorg.libX11
    xorg.libXi
    xorg.libXtst
    stdenv.cc.cc
    libGL
    alsa-lib
    wayland
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    imagemagick
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/fleet
    cp -r $src/bin $out/fleet
    mkdir -p $out/fleet/lib
    cp -r $src/lib/app $out/fleet/lib/app
    cp -r $src/lib/runtime $out/fleet/lib/runtime
    cp $src/lib/Fleet.png $out/fleet/lib/Fleet.png
    cp $src/lib/libapplauncher.so $out/fleet/lib/libapplauncher.so
    cp -r $src/license $out/fleet/license

    mkdir $out/bin
    makeWrapper $out/fleet/bin/Fleet $out/bin/fleet \
      --set _JAVA_AWT_WM_NONREPARENTING 1 \
      --set FLEET_BACKEND_JDK "${pkgs.jetbrains.jdk}"

    mkdir -p $out/share/icons/hicolor/{1024x1024,512x512,256x256,128x128}/apps
    convert $src/lib/Fleet.png -resize 1024x1024 $out/share/icons/hicolor/1024x1024/apps/jetbrains-fleet.png
    convert $src/lib/Fleet.png -resize 512x512 $out/share/icons/hicolor/512x512/apps/jetbrains-fleet.png
    convert $src/lib/Fleet.png -resize 256x256 $out/share/icons/hicolor/256x256/apps/jetbrains-fleet.png
    convert $src/lib/Fleet.png -resize 128x128 $out/share/icons/hicolor/128x128/apps/jetbrains-fleet.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = finalAttrs.pname;
      desktopName = "JetBrains Fleet";
      exec = "fleet";
      icon = "jetbrains-fleet";
      genericName = finalAttrs.meta.description;
      comment = finalAttrs.meta.longDescription;
      categories = [ "Development" ];
      startupWMClass = "Fleet";
    })
  ];

  meta = {
    description = "More Than a Code Editor";
    longDescription = "Fleet is a code editor designed for simplicity, combining a clean UI, AI capabilities, and an essential set of built-in features for most major languages.";
    mainProgram = "fleet";
    homepage = "https://www.jetbrains.com/fleet/";
    license = lib.licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    changelog = "https://www.jetbrains.com/help/fleet/${lib.versions.majorMinor finalAttrs.version}/release-notes-fleet.html";
  };
})