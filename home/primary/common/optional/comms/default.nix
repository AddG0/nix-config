{pkgs, ...}: {
  home.packages =
    builtins.attrValues {
      inherit
        (pkgs)
        slack
        ;
    }
    ++ (
      if pkgs.stdenv.isLinux
      then [pkgs.legcord]
      else [pkgs.discord]
    );
}
