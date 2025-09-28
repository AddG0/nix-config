{
  lib,
  inputs,
  pkgs,
  ...
}: {
  imports = lib.custom.scanPaths ./.;
  xdg.mimeApps.enable = true;
}
