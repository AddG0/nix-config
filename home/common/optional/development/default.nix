{pkgs, ...}: {
  home.packages = with pkgs; [
    ttyplot
    lnav
  ];
}
