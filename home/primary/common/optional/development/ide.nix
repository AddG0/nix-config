{pkgs, ...}: {
  home.packages = with pkgs;
    [
      stable.jetbrains.idea-ultimate
      jetbrains.pycharm-professional
      # jetbrains.phpstorm
      vscode
    ]
    ++ (
      if pkgs.stdenv.isLinux
      then [
        unstable.code-cursor
      ]
      else []
    );
}
