{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.vscodevim.vim
  ];
  userSettings = {
    # Routes d/c/x through the clipboard too — they also write the unnamed register.
    "vim.useSystemClipboard" = true;
  };
}
