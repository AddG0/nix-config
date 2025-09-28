{pkgs, ...}: {
  home.packages = with pkgs; [
    yaml-language-server
    bash-language-server
    nodePackages.unified-language-server
  ];
}
