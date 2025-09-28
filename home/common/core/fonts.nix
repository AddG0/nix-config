{pkgs, ...}: {
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    noto-fonts
    # nerd-fonts.fira-mono # Using specific Fira Mono nerd font package
    meslo-lgs-nf # MesloLGS NF
    fira-code # FiraCode Nerd Font
    hack-font
  ];
}
