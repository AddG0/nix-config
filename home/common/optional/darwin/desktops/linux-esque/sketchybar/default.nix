{
  config,
  pkgs,
  ...
}: {
  home.file.".config/sketchybar".source = ./config;

  home.packages = [
    pkgs.sketchybar-app-font
  ];

  home.activation.reloadSketchybar = ''
    ${pkgs.sketchybar}/bin/sketchybar --reload
  '';
}
