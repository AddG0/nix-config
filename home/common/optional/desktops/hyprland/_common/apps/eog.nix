{
  pkgs,
  lib,
  ...
}: let
  eogDesktop = "org.gnome.eog.desktop";
  imageTypes = [
    "image/png"
    "image/jpeg"
    "image/gif"
    "image/bmp"
    "image/webp"
    "image/tiff"
    "image/svg+xml"
    "image/x-icon"
    "image/vnd.microsoft.icon"
    "image/x-portable-pixmap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-xbitmap"
    "image/x-xpixmap"
    "image/heif"
    "image/avif"
  ];
in {
  xdg.mimeApps.defaultApplications =
    lib.genAttrs imageTypes (_: eogDesktop);

  home.packages = with pkgs; [
    eog
  ];
}
