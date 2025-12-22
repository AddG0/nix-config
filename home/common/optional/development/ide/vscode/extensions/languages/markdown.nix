{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace-release.yzhang.markdown-all-in-one
  ];
  userSettings = {
    "markdown.extension.toc.updateOnSave" = true;
    "markdown.extension.preview.autoShowPreviewToSide" = false;
  };
}
