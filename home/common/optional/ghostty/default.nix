{pkgs, ...}: {
  xdg.configFile."ghostty/config".source = pkgs.writeText "ghostty-config" ''
    ${builtins.readFile ./config}
  ''; #     ${builtins.readFile "${pkgs.themes.catppuccin.ghostty}/share/ghostty-catppuccin/catppuccin-${desktops.catppuccin.flavor}.conf"}

  home.packages = [
    (
      if pkgs.stdenv.isDarwin
      then pkgs.ghostty-bin
      else pkgs.ghostty
    )
  ];
}
