{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.tim-koehler.helm-intellisense
  ];
  userSettings = {
    "helm-intellisense.customValueFileNames" = [
      "values.yaml"
      "values.*.yaml"
      "values-*.yaml"
    ];
  };
}
