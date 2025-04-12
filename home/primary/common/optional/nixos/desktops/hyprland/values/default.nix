{
  lib,
  inputs,
  pkgs,
  ...
}: {
  imports = lib.custom.scanPaths ./.;
}
