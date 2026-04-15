{
  frontmatter,
  lib,
}: let
  normalizeStringList = value:
    if value == null || value == ""
    then []
    else if lib.isList value
    then value
    else let
      trimmed = lib.strings.trim value;
      unwrapped =
        if lib.hasPrefix "[" trimmed && lib.hasSuffix "]" trimmed
        then lib.removeSuffix "]" (lib.removePrefix "[" trimmed)
        else trimmed;
    in
      map (value': let
        trimmed = lib.strings.trim value';
      in
        if lib.hasPrefix "\"" trimmed && lib.hasSuffix "\"" trimmed
        then lib.removeSuffix "\"" (lib.removePrefix "\"" trimmed)
        else if lib.hasPrefix "'" trimmed && lib.hasSuffix "'" trimmed
        then lib.removeSuffix "'" (lib.removePrefix "'" trimmed)
        else trimmed) (lib.splitString "," unwrapped);

  parseClaudeFile = input: let
    parsed = frontmatter.fromFile input;
  in {
    inherit (parsed) body;
    attrs = parsed.attrs or {};
  };

  attrOrNull = attrs: name: attrs.${name} or null;

  parseClaudeMarkdown = input: let
    parsed = parseClaudeFile input;
  in {
    metadata = parsed.attrs;
    inherit (parsed) body;
  };

  fromClaudeAgent = input: let
    parsed = parseClaudeFile input;
  in {
    description = attrOrNull parsed.attrs "description";
    prompt.text = parsed.body;
    tools = normalizeStringList (attrOrNull parsed.attrs "tools");
    skills = normalizeStringList (attrOrNull parsed.attrs "skills");
    model = attrOrNull parsed.attrs "model";
    color = attrOrNull parsed.attrs "color";
    category = attrOrNull parsed.attrs "category";
  };

  fromClaudeCommand = input: let
    parsed = parseClaudeFile input;
    allowedTools = attrOrNull parsed.attrs "allowed-tools";
  in {
    description = attrOrNull parsed.attrs "description";
    argumentHint = attrOrNull parsed.attrs "argument-hint";
    tools = normalizeStringList allowedTools;
    content.text = parsed.body;
  };

  fromClaudeSkillFile = input: let
    parsed = parseClaudeFile input;
    allowedTools = attrOrNull parsed.attrs "allowed-tools";
    tools = attrOrNull parsed.attrs "tools";
  in {
    description = attrOrNull parsed.attrs "description";
    argumentHint = attrOrNull parsed.attrs "argument-hint";
    context = attrOrNull parsed.attrs "context";
    tools = normalizeStringList (
      if allowedTools != null
      then allowedTools
      else tools
    );
    model = attrOrNull parsed.attrs "model";
    version = attrOrNull parsed.attrs "version";
    prompt.text = parsed.body;
  };

  fromClaudeSkillDir = {
    pkgs,
    source,
  }: let
    skill = fromClaudeSkillFile (source + "/SKILL.md");
    entries = builtins.readDir source;
    extraEntries = builtins.removeAttrs entries ["SKILL.md"];
    hasExtras = extraEntries != {};
    resourcesRoot =
      if hasExtras
      then
        pkgs.runCommand "claude-skill-resources" {} ''
          mkdir -p "$out"
          cp -R "${source}/." "$out/"
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
    parseClaudeMarkdown
    ;
}
