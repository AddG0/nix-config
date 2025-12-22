{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ms-azuretools.vscode-docker
    pkgs.vscode-marketplace.ms-azuretools.vscode-containers
  ];
}
