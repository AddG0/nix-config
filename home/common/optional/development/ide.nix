{pkgs, ...}: {
  home.packages = with pkgs;
    [
      stable.jetbrains.idea-ultimate
      jetbrains.pycharm-professional
      jetbrains.datagrip
      jetbrains.webstorm

      # jetbrains.phpstorm
      # vscode
    ]
    ++ (
      if pkgs.stdenv.isLinux
      then [
        code-cursor
        android-studio
      ]
      else []
    );
}
