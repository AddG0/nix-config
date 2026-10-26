{
  config,
  lib,
  pkgs,
  ...
}: let
  codex = config.programs.codex;

  # A key that stops matching upstream's fails on the source read below.
  configDir = import ./codex-home.nix {inherit config lib;};

  configKey = "${configDir}/config.toml";
  profileKey = name: "${configDir}/${name}.config.toml";

  # Upstream mutableSettings' merge rule: Codex refuses an MCP server mixing stdio and HTTP keys, so a declared transport drops the other's.
  mcpTransportFields = {
    stdio = ["command" "args" "env" "env_vars" "cwd"];
    http = ["url" "bearer_token" "bearer_token_env_var" "http_headers" "env_http_headers" "http_headers_helper" "oauth" "oauth_resource" "auth"];
  };
  configMerge = ''
    ($dynamic * $static)
    | reduce (($static.mcp_servers // {}) | to_entries[]) as $server (.;
        if $server.value | has("url") then
          .mcp_servers[$server.key] |= delpaths(${builtins.toJSON mcpTransportFields.stdio} | map([.]))
        elif $server.value | has("command") then
          .mcp_servers[$server.key] |= delpaths(${builtins.toJSON mcpTransportFields.http} | map([.]))
        else
          .
        end)
  '';

  # Merges the file upstream declares at `key` into the writable copy Codex owns.
  mergeInto = key: jqOperation:
    lib.hm.dag.entryAfter ["linkGeneration"] (lib.hm.generators.mkImpureConfigMerger {
      inherit pkgs jqOperation;
      format = "toml";
      empty = "{}";
      path = "${config.home.homeDirectory}/${lib.removePrefix "/" key}";
      staticSettings = config.home.file.${key}.source;
      mode = "600";
    });
in {
  options.programs.codex.writableConfig = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether config.toml and each <profile>.config.toml are writable files
      Codex can save project trust into, with the declared settings merged in
      at activation. Unlike upstream mutableSettings, the declared files stay
      in home.file, disabled, so checks can read them. Needs something for
      config.toml to hold (settings, MCP servers or plugins): with nothing,
      upstream declares no config.toml and evaluation names the missing source.
    '';
  };

  # Under `codex --profile <name>` Codex persists state (project trust, model prompts) into <name>.config.toml, not config.toml.
  config = lib.mkIf (codex.enable && codex.writableConfig) {
    assertions = [
      {
        assertion = !codex.mutableSettings;
        message = "programs.codex: set writableConfig or mutableSettings, not both; mutableSettings drops config.toml from home.file, so writableConfig has nothing to merge";
      }
      {
        assertion = codex.package == null || lib.versionAtLeast (lib.getVersion codex.package) "0.2.0";
        message = "programs.codex.writableConfig merges config.toml, which Codex reads only from 0.2.0; ${lib.getName codex.package} ${lib.getVersion codex.package} reads config.yaml";
      }
    ];

    home.file =
      {${configKey}.enable = false;}
      // lib.mapAttrs' (name: _: lib.nameValuePair (profileKey name) {enable = false;}) codex.profiles;

    home.activation =
      {codexWritableConfig = mergeInto configKey configMerge;}
      // lib.mapAttrs' (name: _: lib.nameValuePair "codexWritableProfile-${name}" (mergeInto (profileKey name) "$dynamic * $static")) codex.profiles;
  };
}
