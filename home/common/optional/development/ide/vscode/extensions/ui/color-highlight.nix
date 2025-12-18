{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.naumovs.color-highlight
  ];
  userSettings = {
    "color-highlight.markerType" = "underline";
    "color-highlight.markRuler" = false;
  };
}
