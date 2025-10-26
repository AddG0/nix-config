{
  pkgs,
  lib,
  ...
}: {
  xdg.configFile."ghostty/config".source = pkgs.writeText "ghostty-config" ''
    ${builtins.readFile ./config}
  ''; #     ${builtins.readFile "${pkgs.themes.catppuccin.ghostty}/share/ghostty-catppuccin/catppuccin-${desktops.catppuccin.flavor}.conf"}

  home.packages = lib.optionals (!pkgs.stdenv.isDarwin) [
    pkgs.ghostty
  ];
}
