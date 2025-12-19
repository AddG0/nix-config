{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.timonwong.shellcheck
  ];
  userSettings = {
    "shellcheck.executablePath" = "${pkgs.shellcheck}/bin/shellcheck";
    "shellcheck.run" = "onSave";
  };
}
