{pkgs, ...}: {
  home.packages = with pkgs;
    [
      jetbrains.idea-ultimate
      # jetbrains.pycharm-professional
      # jetbrains.phpstorm
      vscode
    ]
    ++ (
      if pkgs.stdenv.isLinux
      then [
        code-cursor
      ]
      else []
    );
}
