{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.timonwong.shellcheck
  ];
  userSettings = {
    "shellcheck.executablePath" = "${pkgs.shellcheck}/bin/shellcheck";
    "shellcheck.run" = "onSave";
    # .envrc files are sourced by direnv, not executed as shell scripts
    "shellcheck.ignorePatterns" = {
      "**/.envrc" = true;
      "**/.envrc.private" = true;
      "**/.envrc.local" = true;
    };
  };
}
