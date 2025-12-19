{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ms-kubernetes-tools.vscode-kubernetes-tools
  ];
  userSettings = {
    "vs-kubernetes" = {
      "vs-kubernetes.crd-code-completion" = "enabled";
    };
  };
}
