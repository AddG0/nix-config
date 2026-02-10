{
  pkgs,
  lib,
  ...
}: {
  home.file.".aerospace.toml".source = ./aerospace.toml;

  home.packages = [
    pkgs.aerospace
  ];

  home.activation.reloadAerospace = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${pkgs.aerospace}/bin/aerospace reload-config || true
  '';
}
