{
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
  ];

  # copyApps is enabled by default on stateVersion 25.11+, making apps Spotlight-indexable

  home.packages = with pkgs; [
    pam-reattach
    utm # virtual machine
  ];
}
