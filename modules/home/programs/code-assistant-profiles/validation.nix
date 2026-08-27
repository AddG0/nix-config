{lib}: let
  skillResources = import ./skill-resources.nix {inherit lib;};

  assertExactlyOneTextSource = label: spec: [
    {
      assertion = spec.text != null || spec.source != null;
      message = "${label} must define either text or source";
    }
    {
      assertion = !(spec.text != null && spec.source != null);
      message = "${label} cannot define both text and source";
    }
  ];

  readContent = spec:
    if (spec.text or null) != null
    then spec.text
    else if (spec.source or null) != null
    then builtins.readFile spec.source
    else "";

  countLines = text:
    if text == ""
    then 0
    else builtins.length (lib.splitString "\n" text);

  # A rule with `paths` loads only when Claude opens a matching file, so it is
  # outside the budget. https://code.claude.com/docs/en/memory — under 200 lines.
  alwaysOnParts = sharedConfig:
    lib.optional (readContent (sharedConfig.instructions or {}) != "") {
      name = "instructions";
      text = readContent sharedConfig.instructions;
    }
    ++ lib.mapAttrsToList (name: rule: {
      inherit name;
      text = readContent rule.content;
    }) (lib.filterAttrs (_: rule: rule.paths == []) (sharedConfig.rules or {}));

  measureAlwaysOn = sharedConfig: let
    parts =
      map (part: {
        inherit (part) name;
        lines = countLines part.text;
        characters = lib.stringLength part.text;
      })
      (alwaysOnParts sharedConfig);
    sum = field: lib.foldl (acc: part: acc + part.${field}) 0 parts;
  in {
    inherit parts;
    lines = sum "lines";
    characters = sum "characters";
  };

  # Descending by lines, so the warning names what to cut first.
  formatBreakdown = parts:
    lib.concatMapStringsSep ", " (part: "${part.name} ${toString part.lines}L/${toString part.characters}c")
    (lib.sort (a: b:
      if a.lines == b.lines
      then a.characters > b.characters
      else a.lines > b.lines)
    parts);

  alwaysOnMessages = scope: budget: sharedConfig: let
    measured = measureAlwaysOn sharedConfig;
    overBy = field: unit:
      lib.optional (budget.${field} != null && measured.${field} > budget.${field})
      "${scope}: always-on instructions are ${toString measured.${field}} ${unit} against a budget of ${toString budget.${field}}. Give a rule `paths` so it loads only for matching files, or move the detail into a skill. Breakdown: ${formatBreakdown measured.parts}.";
  in
    overBy "lines" "lines" ++ overBy "characters" "characters";

  # Every skill and agent shares one preloaded listing budget, so an entry taxes
  # all the others whether or not it is invoked.
  selectionEntries = sharedConfig: let
    lengthOf = parts: lib.stringLength (lib.concatStrings (lib.filter (part: part != null) parts));
  in
    lib.mapAttrsToList (name: skill: {
      kind = "skill";
      inherit name;
      length = lengthOf [skill.description (skill.whenToUse or null)];
    }) (sharedConfig.skills or {})
    ++ lib.mapAttrsToList (name: agent: {
      kind = "agent";
      inherit name;
      length = lengthOf [agent.description];
    }) (sharedConfig.agents or {});

  topOffenders = count: entries:
    lib.concatMapStringsSep ", " (entry: "${entry.name} ${toString entry.length}c")
    (lib.take count (lib.sort (a: b: a.length > b.length) entries));

  selectionMessages = scope: budget: sharedConfig: let
    entries = selectionEntries sharedConfig;
    total = lib.foldl (acc: entry: acc + entry.length) 0 entries;
    oversized = lib.filter (entry: budget.characters != null && entry.length > budget.characters) entries;
  in
    lib.optional (budget.total != null && total > budget.total)
    "${scope}: ${toString (lib.length entries)} skills and agents carry ${toString total} characters of selection text against a budget of ${toString budget.total}. Every one is preloaded so the model can pick between them, so drop what you do not use or shorten the longest. Longest: ${topOffenders 5 entries}."
    ++ lib.optional (oversized != [])
    "${scope}: ${toString (lib.length oversized)} descriptions exceed the ${toString budget.characters}-character cap and will be truncated: ${topOffenders 5 oversized}.";

  # Claude Code gives the listing 1% of the window; ~4 chars/token converts it.
  charactersPerToken = 4;

  resolveBudgets = budgets:
    budgets
    // {
      description =
        budgets.description
        // {
          total =
            if budgets.description.total != null
            then budgets.description.total
            else if budgets.contextWindow != null
            then budgets.contextWindow / 100 * charactersPerToken
            else null;
        };
    };

  budgetMessages = scope: budgets: sharedConfig: let
    resolved = resolveBudgets budgets;
  in
    alwaysOnMessages scope resolved.alwaysOn sharedConfig
    ++ selectionMessages scope resolved.description sharedConfig;

  contentFields = ["agents" "commands" "lspServers" "mcpServers" "rules" "skills"];

  # Includes merge last-wins, so two addons claiming one name silently drop one.
  # Scoped to a profile's own list: overriding a parent's is what `extends` is for.
  includeCollisions = profile: let
    keysOf = addon:
      lib.concatMap (
        field: map (name: "${field}.${name}") (lib.attrNames (addon.${field} or {}))
      )
      contentFields;
    claims = lib.zipAttrs (lib.imap0 (index: addon:
      lib.genAttrs (keysOf addon) (_: "include[${toString index}]"))
    (profile.include or []));
  in
    lib.filterAttrs (_: claimants: lib.length claimants > 1) claims;

  collisionAssertions = name: profile:
    lib.mapAttrsToList (key: claimants: {
      assertion = false;
      message = "profile '${name}' includes ${lib.concatStringsSep " and " claimants} which both define ${key}; the later one silently wins. Drop one include or override ${key} on the profile itself.";
    }) (includeCollisions profile);

  # Instructions are optional, so only the both-at-once half of the usual pair
  # applies; an empty spec is how a profile says it adds no instructions.
  instructionsAssertions = scope: sharedConfig: let
    spec = sharedConfig.instructions or {};
  in [
    {
      assertion = !((spec.text or null) != null && (spec.source or null) != null);
      message = "${scope} instructions cannot define both text and source";
    }
  ];

  validateSharedConfig = scope: sharedConfig:
    lib.flatten [
      (instructionsAssertions scope sharedConfig)
      (lib.mapAttrsToList (
        name: agent:
          assertExactlyOneTextSource "${scope} agent '${name}' prompt" agent.prompt
      ) (sharedConfig.agents or {}))
      (lib.mapAttrsToList (
        name: command:
          assertExactlyOneTextSource "${scope} command '${name}' content" command.content
      ) (sharedConfig.commands or {}))
      (lib.mapAttrsToList (
        name: skill: let
          referencesSkillDir = lib.hasInfix "\${SKILL_DIR}" (readContent skill.prompt);
        in
          assertExactlyOneTextSource "${scope} skill '${name}' prompt" skill.prompt
          ++ lib.optionals (skill.resourcesRoot != null && skillResources.inspectableAtEval skill.resourcesRoot)
          (map (file: {
              assertion = !(builtins.pathExists (skill.resourcesRoot + "/${file}"));
              message = skillResources.message scope name file;
            })
            skillResources.names)
          ++ [
            {
              assertion = !referencesSkillDir || skill.resourcesRoot != null;
              message = "${scope} skill '${name}' prompt references \${SKILL_DIR} but no resourcesRoot is set; either point resourcesRoot at a directory containing the referenced files, or remove the \${SKILL_DIR} references";
            }
          ]
      ) (sharedConfig.skills or {}))
      (lib.mapAttrsToList (
        name: rule:
          assertExactlyOneTextSource "${scope} rule '${name}' content" rule.content
      ) (sharedConfig.rules or {}))
      (lib.mapAttrsToList (name: server: [
        {
          assertion =
            if server.type == "local"
            then server.command != null
            else server.url != null;
          message = "${scope} MCP server '${name}' must define command for local servers or url for remote servers";
        }
        {
          assertion =
            if server.type == "local"
            then server.url == null
            else server.command == null;
          message = "${scope} MCP server '${name}' cannot define both local and remote connection fields";
        }
      ]) (sharedConfig.mcpServers or {}))
    ];
in {
  inherit alwaysOnMessages assertExactlyOneTextSource budgetMessages collisionAssertions includeCollisions measureAlwaysOn resolveBudgets selectionEntries selectionMessages validateSharedConfig;
}
