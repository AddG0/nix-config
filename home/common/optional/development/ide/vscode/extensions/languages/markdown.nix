{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace-release.yzhang.markdown-all-in-one
    pkgs.vscode-marketplace.bierner.markdown-mermaid
  ];
  userSettings = {
    "markdown.extension.toc.updateOnSave" = true;
    "markdown.extension.preview.autoShowPreviewToSide" = false;
  };
}
