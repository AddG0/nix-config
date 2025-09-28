{pkgs, ...}: {
  home.file.".aerospace.toml".source = ./aerospace.toml;

  home.packages = [
    pkgs.aerospace
  ];

  home.activation.reloadAerospace = ''
    ${pkgs.aerospace}/bin/aerospace reload-config
  '';
}
