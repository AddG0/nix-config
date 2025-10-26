{pkgs, ...}: {
  home.packages = with pkgs; [
    _1password-gui
    _1password-cli
    age-plugin-1p
  ];
}
