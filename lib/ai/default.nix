{
  frontmatter,
  lib,
}: let
  inherit (frontmatter) normalizeStringList;

  assertPathExists = fnName: path:
    if builtins.pathExists path
    then path
    else throw "${fnName}: source path does not exist: ${toString path}";

  parseClaudeFile = input: let
    parsed = frontmatter.fromFile input;
  in {
    inherit (parsed) body;
    attrs = parsed.attrs or {};
  };

  fromClaudeAgent = rawInput: let
    input = assertPathExists "fromClaudeAgent" rawInput;
    parsed = parseClaudeFile input;
    description =
      parsed.attrs.description
      or (throw "fromClaudeAgent: ${toString input} is missing required 'description' frontmatter field");
  in {
    inherit description;
    prompt.text = parsed.body;
    tools = normalizeStringList (parsed.attrs.tools or null);
    skills = normalizeStringList (parsed.attrs.skills or null);
    model = parsed.attrs.model or null;
    color = parsed.attrs.color or null;
    category = parsed.attrs.category or null;
  };

  fromClaudeCommand = rawInput: let
    input = assertPathExists "fromClaudeCommand" rawInput;
    parsed = parseClaudeFile input;
  in {
    description = parsed.attrs.description or null;
    argumentHint = parsed.attrs."argument-hint" or null;
    allowedTools = normalizeStringList (parsed.attrs."allowed-tools" or null);
    content.text = parsed.body;
  };

  fromClaudeSkillFile = rawInput: let
    input = assertPathExists "fromClaudeSkillFile" rawInput;
    parsed = parseClaudeFile input;
    allowedTools = parsed.attrs."allowed-tools" or null;
    tools = parsed.attrs.tools or null;
    description =
      parsed.attrs.description
      or (throw "fromClaudeSkillFile: ${toString input} is missing required 'description' frontmatter field");
  in {
    inherit description;
    argumentHint = parsed.attrs."argument-hint" or null;
    context = parsed.attrs.context or null;
    allowedTools = normalizeStringList (
      if allowedTools != null
      then allowedTools
      else tools
    );
    model = parsed.attrs.model or null;
    version = parsed.attrs.version or null;
    prompt.text = parsed.body;
  };

  fromClaudeSkillDir = {
    pkgs,
    source,
  }: let
    source' = assertPathExists "fromClaudeSkillDir" source;
    skill = fromClaudeSkillFile (source' + "/SKILL.md");
    entries = builtins.readDir source';
    extraEntries = builtins.removeAttrs entries ["SKILL.md"];
    hasExtras = extraEntries != {};
    resourcesRoot =
      if hasExtras
      then
        pkgs.runCommand "claude-skill-resources" {} ''
          mkdir -p "$out"
          cp -R "${source'}/." "$out/"
          rm -f "$out/SKILL.md"
        ''
      else null;
  in
    skill // lib.optionalAttrs (resourcesRoot != null) {inherit resourcesRoot;};
in {
  inherit
    fromClaudeAgent
    fromClaudeCommand
    fromClaudeSkillDir
    fromClaudeSkillFile
    ;
}
