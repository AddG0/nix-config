{
  lib,
  pkgs,
  inputs,
  system,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
  ];

  home.packages = with pkgs; [
  ];
}
