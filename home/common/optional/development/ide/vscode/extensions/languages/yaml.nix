{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.redhat.vscode-yaml
  ];
  userSettings = {
    "yaml.schemas" = {
      # Kustomize. We override the schemaStore because then it doesn't find random schemas to try to validate against
      "https://json.schemastore.org/kustomization.json" = "kustomization.yaml";
    };
    "yaml.validate" = true;
    "yaml.completion" = true;
    "yaml.hover" = true;
    "yaml.schemaStore.enable" = true;
  };
}
