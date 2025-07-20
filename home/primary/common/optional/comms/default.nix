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
      then [pkgs.discord-legcord]
      else [pkgs.discord]
    );
}
