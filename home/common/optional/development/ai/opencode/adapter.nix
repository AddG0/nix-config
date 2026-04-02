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

  # Named CSS colors to hex for opencode compatibility
  namedColors = {
    black = "#000000";
    white = "#FFFFFF";
    red = "#EF4444";
    green = "#22C55E";
    blue = "#3B82F6";
    yellow = "#EAB308";
    orange = "#F97316";
    purple = "#A855F7";
    pink = "#EC4899";
    cyan = "#06B6D4";
    gray = "#6B7280";
    grey = "#6B7280";
  };

  # Convert "color: name" to "color: #hex" if it's a known named color
  convertColorLine = line: let
    stripped = lib.removePrefix "color: " line;
  in
    if lib.hasPrefix "color: " line && namedColors ? ${stripped}
    then "color: \"${namedColors.${stripped}}\""
    else line;

  # Adapt Claude-specific frontmatter fields for opencode:
  # - Strip tools/model (opencode uses different formats)
  # - Convert named colors to hex
  adaptAgentContent = content: let
    text =
      if lib.isPath content
      then builtins.readFile content
      else if lib.isDerivation content
      then builtins.readFile (toString content)
      else content;
  in
    lib.concatStringsSep "\n" (
      map convertColorLine (
        builtins.filter (
          line:
            !(lib.hasPrefix "tools:" line || lib.hasPrefix "model:" line)
        ) (lib.splitString "\n" text)
      )
    );

  adaptAgents = lib.mapAttrs (_: adaptAgentContent);

  # Transform claude-code MCP server format to opencode format:
  #   claude: { command = "bin"; args = ["a"]; env = { K = "V"; }; }
  #   opencode: { type = "local"; command = ["bin" "a"]; environment = { K = "V"; }; }
  adaptMcp = lib.mapAttrs (
    _: server:
      if (server.type or "") == "http"
      then {
        type = "remote";
        inherit (server) url;
      }
      else
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
