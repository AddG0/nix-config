{lib, ...}: let
in {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
  ];
}
