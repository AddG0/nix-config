{pkgs, ...}: {
  extensions = [
    # We use release version here to fix issue with the selected line being red
    pkgs.vscode-marketplace-release.catppuccin.catppuccin-vsc
    pkgs.vscode-marketplace-release.catppuccin.catppuccin-vsc-icons
  ];
  userSettings = {
    "workbench.colorTheme" = "Catppuccin Mocha";
  };
}
