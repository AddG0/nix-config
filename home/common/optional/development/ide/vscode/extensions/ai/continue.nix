{
  pkgs,
  hostSpec,
}: {
  extensions = [
    pkgs.vscode-marketplace.continue.continue
  ];
  userSettings = {
    "continue.enableTabAutocomplete" = true;
    "yaml.schemas" = {
      "file:///${hostSpec.homedir}.vscode/extensions/continue.continue/config-yaml-schema.json" = [
        ".continue/**/*.yaml"
      ];
    };
  };
}
