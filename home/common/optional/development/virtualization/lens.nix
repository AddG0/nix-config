{pkgs, ...}: {
  home.packages = with pkgs; [
    lens # preview kubernetes resources
    kubelogin
  ];
}
