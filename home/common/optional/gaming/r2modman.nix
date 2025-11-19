{pkgs, ...}: {
  home.packages = with pkgs; [
    r2modman # Unofficial Thunderstore mod manager
  ];
}
