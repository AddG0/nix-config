{pkgs, ...}: {
  imports = [
    ./sops.nix
  ];

  home.packages = with pkgs; [
    sops
    age
  ];
}
