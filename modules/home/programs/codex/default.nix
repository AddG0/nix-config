{
  config,
  lib,
  pkgs,
  ...
}: let
  codex = config.programs.codex;

  # A key that stops matching upstream's fails on the source read below.
  configDir = import ./codex-home.nix {inherit config lib;};

  profileKey = name: "${configDir}/${name}.config.toml";
in {
  imports = [
    (lib.mkRenamedOptionModule ["programs" "codex" "mutableConfig" "enable"] ["programs" "codex" "mutableSettings"])
  ];

  # Under `codex --profile <name>` Codex persists state (project trust, model prompts) into <name>.config.toml, not config.toml.
  config = lib.mkIf (codex.enable && codex.mutableSettings) {
    home.file = lib.mapAttrs' (name: _: lib.nameValuePair (profileKey name) {enable = false;}) codex.profiles;

    home.activation = lib.mapAttrs' (name: _:
      lib.nameValuePair "codexMutableProfile-${name}" (lib.hm.dag.entryAfter ["linkGeneration"] (lib.hm.generators.mkImpureConfigMerger {
        inherit pkgs;
        format = "toml";
        empty = "{}";
        jqOperation = "$dynamic * $static";
        path = "${config.home.homeDirectory}/${lib.removePrefix "/" (profileKey name)}";
        staticSettings = config.home.file.${profileKey name}.source;
        mode = "600";
      })))
    codex.profiles;
  };
}
