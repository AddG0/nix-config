{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.catppuccin.catppuccin-vsc
    pkgs.vscode-marketplace.catppuccin.catppuccin-vsc-icons
  ];
  userSettings = {
    "workbench.colorTheme" = "Catppuccin Mocha";
    "workbench.iconTheme" = "catppuccin-mocha";
  };
}
