{pkgs, ...}: {
  home.packages = [
    pkgs.gita # Multi-repo management CLI.
  ];

  home.shellAliases = {
    gs = "gita super";
    gsa = "gita super add";
    gsc = "gita super commit";
    gsp = "gita super push";
    gspl = "gita super pull";
    gsf = "gita super fetch --all";
    gsco = "gita super checkout";
    gsl = "gita super pull";
    gsll = "gita ll";
  };
}
