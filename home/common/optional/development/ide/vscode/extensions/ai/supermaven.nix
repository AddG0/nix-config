{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.supermaven.supermaven
  ];
  userSettings = {};
}
