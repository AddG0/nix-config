# Reading a resolved profile's content the way every target needs it.
{lib}: let
  inherit (import ./options/profile.nix {inherit lib;}) entryTypes;

  readContent = spec:
    if spec.text != null
    then spec.text
    else if spec.source != null
    then builtins.readFile spec.source
    else "";

  # Both forms count: a source-only block renders to a file for claude-code, but has to be inlined elsewhere.
  hasInstructions = profile: profile.instructions.text != null || profile.instructions.source != null;

  # A rule inlined into one context string: titled when it has a description or paths, then its scope.
  inlineRule = name: rule: let
    body = readContent rule.content;
    header = lib.optional (rule.paths != []) "Applies to: ${lib.concatStringsSep ", " rule.paths}";
    # Not `description or name`: the attribute exists and defaults to null, which `or` does not catch.
    title = lib.optional (rule.description != null || rule.paths != []) "## ${
      if rule.description != null
      then rule.description
      else name
    }";
    sections = lib.filter (part: part != "") (title ++ header ++ [body]);
  in
    lib.concatStringsSep "\n\n" sections;

  # Instructions then every rule, for a tool that loads one context string per session.
  inlinedSections = profile:
    lib.filter (s: s != "") (
      lib.optional (hasInstructions profile) (readContent profile.instructions)
      ++ lib.mapAttrsToList inlineRule profile.rules
    );

  # For a tool whose skill frontmatter has only `description`, so `whenToUse` has to ride along in it.
  skillDescription = skill: let
    base =
      if skill.description != null
      then skill.description
      else skill.name;
  in
    if skill.whenToUse != null && skill.whenToUse != ""
    then "${base}\n\n${skill.whenToUse}"
    else base;

  withExtraFor = target: entry: attrs: lib.recursiveUpdate attrs entry.extra.${target};

  # `name` defaults to the entry's key, so it is compared per entry below.
  entryDefaults = lib.mapAttrs (kind: type:
    (lib.evalModules {
      modules = [
        {
          options.${kind} = lib.mkOption {type = lib.types.attrsOf type;};
          config.${kind}.default = {};
        }
      ];
    })
      .config
      .${
      kind
    }
      .default)
  entryTypes;

  # The fields an entry sets away from its type default; `extra` counts per target, as `extra.<target>`.
  setFields = kind: name: entry: let
    defaults = entryDefaults.${kind} // {inherit name;};
    plain = lib.filter (field: field != "extra" && entry.${field} != defaults.${field}) (lib.attrNames defaults);
    extras = map (target: "extra.${target}") (lib.attrNames (lib.filterAttrs (_: value: value != {}) entry.extra));
  in
    plain ++ extras;

  always = _: true;

  # `reads.<kind>.<field>` says whether a tool expresses that value; a set field it lacks or rejects is dropped.
  droppedFields = reads: profile: let
    fieldsOf = kind: lib.attrNames (removeAttrs entryDefaults.${kind} ["extra"]) ++ map (target: "extra.${target}") (lib.attrNames entryDefaults.${kind}.extra);
    unknown = lib.concatLists (lib.mapAttrsToList (kind: kindReads: map (field: "${kind}.${field}") (lib.subtractLists (fieldsOf kind) (lib.attrNames kindReads))) reads);
  in
    lib.throwIf (unknown != []) "code-assistant-profiles: a target's `reads` names fields its entry types lack: ${lib.concatStringsSep ", " unknown}"
    lib.filterAttrs (_: entries: entries != {}) (lib.mapAttrs (kind: kindReads:
      lib.filterAttrs (_: fields: fields != []) (lib.mapAttrs (name: entry:
        lib.filter (field: !(kindReads ? ${field}) || !(kindReads.${field} (lib.attrByPath (lib.splitString "." field) null entry)))
        (setFields kind name entry))
      profile.${kind}))
    reads);
in {
  inherit always droppedFields inlineRule inlinedSections readContent skillDescription withExtraFor;
}
