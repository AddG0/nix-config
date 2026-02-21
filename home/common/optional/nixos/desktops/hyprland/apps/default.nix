{lib, ...}: {
  imports = lib.custom.scanPaths ./.;
  xdg.mimeApps.enable = true;
}
