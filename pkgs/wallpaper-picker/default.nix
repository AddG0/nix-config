# Smoke-test (theming + per-output folders come from wallpaper.nix's launcher):
#   WP_BASE=$HOME/Pictures/wallpapers nix run .#wallpaper-picker
# Other env: WP_FOLDERS (JSON output→folder), WP_BG / WP_FG / WP_BORDER.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  nodejs,
  quickshell,
  hyprland,
  wpaperd,
}:
stdenvNoCC.mkDerivation {
  pname = "wallpaper-picker";
  version = "0.1.0";

  src = ./.;

  # Local package: src = ./. has no upstream URL for nix-update to bump.
  passthru.nixUpdate.version = "skip";

  nativeBuildInputs = [makeWrapper];
  nativeCheckInputs = [nodejs];

  # Pure-logic unit tests (bounds math, folder lookup). Display-free, so
  # they run in the build sandbox. Rendering is not covered.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    node --test test.js
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/wallpaper-picker
    cp shell.qml \
       MonitorSelector.qml MonitorButton.qml \
       ThumbnailGrid.qml Thumbnail.qml \
       util.js \
       $out/share/wallpaper-picker/

    mkdir -p $out/bin
    makeWrapper ${lib.getExe quickshell} $out/bin/wallpaper-picker \
      --add-flags "-p $out/share/wallpaper-picker/shell.qml" \
      --set-default WP_HYPRCTL ${lib.getExe' hyprland "hyprctl"} \
      --set-default WP_WPAPERCTL ${lib.getExe' wpaperd "wpaperctl"}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Quickshell-based wallpaper picker showing each monitor's layout with thumbnails";
    platforms = platforms.linux;
    mainProgram = "wallpaper-picker";
  };
}
