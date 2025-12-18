{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.pkief.material-icon-theme
  ];
  userSettings = {
    "workbench.iconTheme" = "material-icon-theme";
  };
}
