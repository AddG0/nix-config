{lib, ...}: let
in {
  imports = lib.flatten [
    ../common
    (lib.custom.scanPaths ./.)
  ];
}
