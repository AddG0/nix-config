# VSCode Server configuration for remote SSH sessions
# Creates extensions and settings symlinks in ~/.vscode-server/
{
  inputs,
  lib,
  pkgs,
  config,
  hostSpec,
  ...
}: let
  # Import shared extension library
  vscodeLib = import ./lib.nix {inherit lib pkgs config hostSpec;};
  jsonFormat = pkgs.formats.json {};

  inherit (vscodeLib.defaultProfile) extensions;

  # Generate extensions.json manifest (required for VS Code to recognize extensions)
  extensionsJson = pkgs.writeText "extensions.json" (builtins.toJSON (
    map (ext: {
      identifier = {
        id = "${ext.vscodeExtPublisher}.${ext.vscodeExtName}";
      };
      inherit (ext) version;
      location = {
        "$mid" = 1;
        path = "/home/${config.home.username}/.vscode-server/extensions/${ext.vscodeExtPublisher}.${ext.vscodeExtName}";
        scheme = "file";
      };
      relativeLocation = "${ext.vscodeExtPublisher}.${ext.vscodeExtName}";
    })
    extensions
  ));

  # Read settings from the module system (config) so mkForce/mkDefault are already
  # resolved, and Stylix overrides are properly merged — matching what home-manager's
  # VSCode module does internally.
  settingsJson = jsonFormat.generate "vscode-server-settings.json" config.programs.vscode.profiles.default.userSettings;

  # Create individual extension symlinks (like home-manager vscode module)
  extensionLinks = lib.listToAttrs (map (ext: {
      name = ".vscode-server/extensions/${ext.vscodeExtPublisher}.${ext.vscodeExtName}";
      value = {
        source = "${ext}/share/vscode/extensions/${ext.vscodeExtPublisher}.${ext.vscodeExtName}";
      };
    })
    extensions);
in {
  imports = [
    inputs.vscode-server.homeModules.default
  ];

  services.vscode-server.enable = true;

  home.file =
    extensionLinks
    // {
      # Add extensions.json manifest
      ".vscode-server/extensions/extensions.json".source = extensionsJson;

      # Symlink settings.json to vscode-server's machine settings
      ".vscode-server/data/Machine/settings.json".source = settingsJson;
    };
}
