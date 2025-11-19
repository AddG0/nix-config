{pkgs, ...}: {
  home.packages = with pkgs;
    [
      jetbrains.idea-ultimate
      jetbrains.pycharm-professional
      jetbrains.datagrip
      jetbrains.webstorm
      jetbrains.fleet

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
