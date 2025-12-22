{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace-release.supermaven.supermaven
  ];
  userSettings = {};
}
