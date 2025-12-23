{pkgs, ...}: {
  home.packages = with pkgs;
    [
      jetbrains.idea-ultimate
      jetbrains.pycharm-professional
      jetbrains.datagrip
      jetbrains.webstorm

      # jetbrains.phpstorm
      # vscode
      code-cursor
    ]
    ++ (
      if pkgs.stdenv.isLinux
      then [
        android-studio
      ]
      else []
    );
}
