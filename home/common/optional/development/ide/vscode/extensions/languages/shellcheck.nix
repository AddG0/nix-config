{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.timonwong.shellcheck
  ];
  userSettings = {
    "shellcheck.executablePath" = "shellcheck";
    "shellcheck.run" = "onSave";
  };
}
