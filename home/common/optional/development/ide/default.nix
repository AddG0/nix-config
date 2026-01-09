{pkgs, ...}: {
  home.packages = with pkgs;
    [
      jetbrains.idea
      jetbrains.pycharm
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
