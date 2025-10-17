{pkgs, ...}: {
  home.packages = with pkgs;
    [
      stable.jetbrains.idea-ultimate
      jetbrains.pycharm-professional
      jetbrains.datagrip
      jetbrains.webstorm
      android-studio

      # jetbrains.phpstorm
      # vscode
    ]
    ++ (
      if pkgs.stdenv.isLinux
      then [
        unstable.code-cursor
      ]
      else []
    );
}
