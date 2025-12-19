{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ms-toolsai.jupyter
    pkgs.vscode-marketplace.ms-toolsai.jupyter-keymap
    pkgs.vscode-marketplace.ms-toolsai.jupyter-renderers
    pkgs.vscode-marketplace.ms-toolsai.vscode-jupyter-cell-tags
    pkgs.vscode-marketplace.ms-toolsai.vscode-jupyter-slideshow
  ];
  userSettings = {
    "jupyter.askForKernelRestart" = false;
    "notebook.cellToolbarLocation" = {
      "default" = "right";
      "jupyter-notebook" = "left";
    };
  };
}
