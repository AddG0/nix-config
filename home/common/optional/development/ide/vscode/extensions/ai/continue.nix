{
  pkgs,
  config,
  ...
}: {
  extensions = [
    pkgs.vscode-marketplace.continue.continue
  ];
  userSettings = {
    "continue.enableTabAutocomplete" = true;
    "yaml.schemas" = {
      "file:///${config.hostSpec.home}.vscode/extensions/continue.continue/config-yaml-schema.json" = [
        ".continue/**/*.yaml"
      ];
    };
  };
}
