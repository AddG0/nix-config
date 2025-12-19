{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.supermaven.supermaven
  ];
  userSettings = {
    # Enable inline suggestions
    "supermaven.enable.inline" = true;
  };
}
