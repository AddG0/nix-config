{pkgs, ...}: {
  home.packages = builtins.attrValues {
    inherit
      (pkgs)
      legcord
      slack
      ;
  };
}
