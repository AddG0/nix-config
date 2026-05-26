{pkgs, ...}: {
  home.packages = [pkgs.mani];

  home.shellAliases = {
    mr = "mani run";
    me = "mani exec";
    ml = "mani list";
    msy = "mani sync";
  };
}
