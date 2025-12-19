{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.zainchen.json
  ];
  userSettings = {
    "json.maxItemsComputed" = 10000;
  };
}
