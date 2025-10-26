{lib, ...}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
  ];
}
