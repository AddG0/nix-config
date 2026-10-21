# Context budgets: how much a resolved profile loads before its first prompt, and how much selection text it preloads.
{lib}: let
  inherit (import ./content.nix {inherit lib;}) readContent;

  countLines = text:
    if text == ""
    then 0
    else builtins.length (lib.splitString "\n" text);

  # A rule with `paths` loads only when Claude opens a matching file, so it is outside the budget.
  alwaysOnParts = inlineScoped: sharedConfig:
    lib.optional (readContent sharedConfig.instructions != "") {
      name = "instructions";
      text = readContent sharedConfig.instructions;
    }
    ++ lib.mapAttrsToList (name: rule: {
      inherit name;
      text = readContent rule.content;
    }) (lib.filterAttrs (_: rule: inlineScoped || rule.paths == []) sharedConfig.rules);

  measureWith = inlineScoped: sharedConfig: let
    parts =
      map (part: {
        inherit (part) name;
        lines = countLines part.text;
        characters = lib.stringLength part.text;
      })
      (alwaysOnParts inlineScoped sharedConfig);
    sum = field: lib.foldl (acc: part: acc + part.${field}) 0 parts;
  in {
    inherit parts;
    lines = sum "lines";
    characters = sum "characters";
  };

  measureAlwaysOn = measureWith false;
  # Codex and opencode cannot scope a rule, so they inline it into every session.
  measureInlined = measureWith true;

  # Descending by lines, so the warning names what to cut first.
  formatBreakdown = parts:
    lib.concatMapStringsSep ", " (part: "${part.name} ${toString part.lines}L/${toString part.characters}c")
    (lib.sort (a: b:
      if a.lines == b.lines
      then a.characters > b.characters
      else a.lines > b.lines)
    parts);

  alwaysOnMessagesWith = measure: scope: budget: sharedConfig: let
    measured = measure sharedConfig;
    overBy = field: unit:
      lib.optional (budget.${field} != null && measured.${field} > budget.${field})
      "${scope}: always-on instructions are ${toString measured.${field}} ${unit} against a budget of ${toString budget.${field}}. Give a rule `paths` so it loads only for matching files, or move the detail into a skill. Breakdown: ${formatBreakdown measured.parts}.";
  in
    overBy "lines" "lines" ++ overBy "characters" "characters";

  alwaysOnMessages = alwaysOnMessagesWith measureAlwaysOn;

  # Every skill and agent shares one preloaded listing budget, invoked or not.
  selectionEntries = sharedConfig: let
    lengthOf = parts: lib.stringLength (lib.concatStrings (lib.filter (part: part != null) parts));
  in
    lib.mapAttrsToList (name: skill: {
      kind = "skill";
      inherit name;
      length = lengthOf [skill.description skill.whenToUse];
    })
    sharedConfig.skills
    ++ lib.mapAttrsToList (name: agent: {
      kind = "agent";
      inherit name;
      length = lengthOf [agent.description];
    })
    sharedConfig.agents;

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
  listingWindowDivisor = 100;
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
            then budgets.contextWindow / listingWindowDivisor * charactersPerToken
            else null;
        };
    };

  budgetMessages = scope: budgets: sharedConfig: let
    resolved = resolveBudgets budgets;
  in
    alwaysOnMessages scope resolved.alwaysOn sharedConfig
    ++ selectionMessages scope resolved.description sharedConfig;

  # Silent when no rule is path-scoped: the plain check already said it all.
  inlinedBudgetMessages = scope: budgets: sharedConfig:
    lib.optionals (lib.any (rule: rule.paths != []) (lib.attrValues sharedConfig.rules))
    (alwaysOnMessagesWith measureInlined "${scope} as codex/opencode inline it" budgets.alwaysOn sharedConfig);
in {
  inherit budgetMessages inlinedBudgetMessages measureAlwaysOn measureInlined resolveBudgets selectionEntries selectionMessages;
}
