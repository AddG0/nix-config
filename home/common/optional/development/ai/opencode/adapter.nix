{
  config,
  lib,
  ...
}: let
  ccCfg = config.programs.claude-code-profiles;
  profile = ccCfg.resolved.${ccCfg.defaultProfile};

  # Coerce derivations to string store paths so the opencode module handles them
  # correctly as directory sources rather than trying to use them as text.
  coerce = lib.mapAttrs (
    _: v:
      if lib.isDerivation v
      then toString v
      else v
  );

  # Strip Claude-specific frontmatter fields (tools, model) from agent markdown
  # since opencode expects different formats for these.
  stripClaudeFields = content: let
    text =
      if lib.isPath content
      then builtins.readFile content
      else if lib.isDerivation content
      then builtins.readFile (toString content)
      else content;
  in
    builtins.replaceStrings
    ["\n"]
    ["\n"]
    (lib.concatStringsSep "\n" (
      builtins.filter (
        line:
          !(lib.hasPrefix "tools:" line || lib.hasPrefix "model:" line)
      ) (lib.splitString "\n" text)
    ));

  adaptAgents = lib.mapAttrs (_: stripClaudeFields);

  # Transform claude-code MCP server format to opencode format:
  #   claude: { command = "bin"; args = ["a"]; env = { K = "V"; }; }
  #   opencode: { type = "local"; command = ["bin" "a"]; environment = { K = "V"; }; }
  adaptMcp = lib.mapAttrs (
    _: server:
      {
        type = "local";
        command = [server.command] ++ (server.args or []);
      }
      // lib.optionalAttrs (server ? env) {environment = server.env;}
  );

  rulesTexts = lib.mapAttrsToList (
    _: v:
      if lib.isString v
      then v
      else builtins.readFile v
  ) (profile.rules or {});

  combinedRules = lib.concatStringsSep "\n\n" (
    lib.filter (s: s != "") (
      lib.optional ((profile.memory.text or null) != null) profile.memory.text
      ++ rulesTexts
    )
  );
in {
  config = lib.mkIf (ccCfg.enable && config.programs.opencode.enable) {
    programs.opencode = {
      agents = lib.mkDefault (adaptAgents (profile.agents or {}));
      commands = lib.mkDefault (coerce (profile.commands or {}));
      skills = lib.mkDefault (coerce (profile.skills or {}));
      settings.mcp = lib.mkDefault (adaptMcp (profile.mcpServers or {}));
      rules = lib.mkDefault combinedRules;
    };
  };
}
