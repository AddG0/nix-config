{
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
  ];

  home.packages = with pkgs; [
    pam-reattach
    utm # virtual machine
  ];
}
