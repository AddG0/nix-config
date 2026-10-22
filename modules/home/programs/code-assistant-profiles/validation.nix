{lib}: let
  inherit (import ./options/profile.nix {inherit lib;}) entryTypes;
  skillResources = import ./skill-resources.nix {inherit lib;};
  inherit (import ./content.nix {inherit lib;}) readContent;

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

  entryKinds = lib.attrNames entryTypes;

  # Includes merge last-wins, so two addons in one profile's list claiming a name silently drop one.
  includeCollisions = profile: let
    keysOf = addon:
      lib.concatMap (
        kind: map (name: "${kind}.${name}") (lib.attrNames (addon.${kind} or {}))
      )
      entryKinds;
    claims = lib.zipAttrs (lib.imap0 (index: addon:
      lib.genAttrs (keysOf addon) (_: "include[${toString index}]"))
    profile.include);
  in
    lib.filterAttrs (_: claimants: lib.length claimants > 1) claims;

  collisionAssertions = name: profile:
    lib.mapAttrsToList (key: claimants: {
      assertion = false;
      message = "profile '${name}' includes ${lib.concatStringsSep " and " claimants} which both define ${key}; the later one silently wins. Drop one include or override ${key} on the profile itself.";
    }) (includeCollisions profile);

  # Instructions are optional, so an empty spec is allowed and only both-at-once is an error.
  instructionsAssertions = scope: sharedConfig: let
    spec = sharedConfig.instructions;
  in [
    {
      assertion = !(spec.text != null && spec.source != null);
      message = "${scope} instructions cannot define both text and source";
    }
  ];

  oauthSet = server: server.oauth.clientId != null || server.oauth.callbackPort != null || server.oauth.scopes != [];

  entryLabels = {
    agents = "agent";
    commands = "command";
    skills = "skill";
    rules = "rule";
    mcpServers = "MCP server";
    lspServers = "LSP server";
  };

  showPath = lib.concatMapStringsSep "" (step:
    if lib.isInt step
    then "[${toString step}]"
    else ".${step}");

  # Stops at derivations and module internals, which a type check never needs and which can be huge or cyclic.
  forced = value:
    if lib.isDerivation value
    then true
    else if lib.isAttrs value
    then lib.all forced (lib.attrValues (removeAttrs value ["_module"]))
    else if lib.isList value
    then lib.all forced value
    else true;

  # The module system's own verdict: one option of `type`, defined as `value`, evaluated all the way down.
  accepts = type: value:
    (builtins.tryEval (forced
      (lib.evalModules {
        modules = [
          {
            options.value = lib.mkOption {inherit type;};
            config.value = value;
          }
        ];
      })
      .config
      .value))
    .success;

  # Names what an option set rejects in `value`, key by key: nested option groups, declared options, then the freeform type.
  optionSetProblems = options: freeformType: path: value:
    lib.concatLists (lib.mapAttrsToList (key: field: let
      at = path ++ [key];
    in
      if lib.isOption (options.${key} or null)
      then typeProblems options.${key}.type at field
      else if options ? ${key} && lib.isAttrs options.${key} && lib.isAttrs field
      then optionSetProblems options.${key} null at field
      else if freeformType != null
      then typeProblems (freeformType.nestedTypes.elemType or freeformType) at field
      else ["sets `${lib.removePrefix "." (showPath at)}`, which is not an option"])
    value);

  submoduleProblems = type: path: value: let
    # Unknown keys are reported below, by name, rather than thrown.
    evaluated = lib.evalModules {
      modules =
        type.getSubModules
        ++ [
          {
            _module.check = false;
            _module.args.name = lib.mkDefault (
              if path != [] && lib.isString (lib.last path)
              then lib.last path
              else "<name>"
            );
          }
          {config = value;}
        ];
    };
  in
    optionSetProblems (removeAttrs evaluated.options ["_module"]) evaluated._module.freeformType path value;

  # Checks a value against any option type through the module system, then walks into submodules and containers only to name the failing field or element.
  typeProblems = type: path: value: let
    mismatch = "${lib.removePrefix "." (showPath path)} is ${lib.generators.toPretty {} value}, which is not ${type.description}";
    inner = type.nestedTypes.elemType or null;
    containers = ["submodule" "listOf" "nonEmptyListOf" "attrsOf" "lazyAttrsOf"];
    located =
      if type.name == "submodule" && lib.isAttrs value && !lib.isDerivation value
      then submoduleProblems type path value
      else if inner == null
      then []
      # A scalar inside nullOr keeps the outer description, which names null as allowed.
      else if type.name == "nullOr" && value != null && lib.elem inner.name containers
      then typeProblems inner path value
      else if lib.elem type.name ["listOf" "nonEmptyListOf"] && lib.isList value
      then lib.concatLists (lib.imap0 (index: typeProblems inner (path ++ [index])) value)
      else if lib.elem type.name ["attrsOf" "lazyAttrsOf"] && lib.isAttrs value
      then lib.concatLists (lib.mapAttrsToList (key: typeProblems inner (path ++ [key])) value)
      else [];
  in
    if accepts type value
    then []
    else if located != []
    then located
    else [mismatch];

  # Checks every entry of an untyped layer (a merged profile, an addon, baseConfig) against its option type, naming the entry.
  fieldTypeProblems = scope: sharedConfig:
    lib.concatLists (lib.mapAttrsToList (kind: label:
      lib.concatLists (lib.mapAttrsToList (name: entry:
        map (problem: "${scope} ${label} '${name}' ${problem}") (typeProblems entryTypes.${kind} [] entry))
      sharedConfig.${kind}))
    entryLabels);

  validateSharedConfig = scope: sharedConfig:
    lib.flatten [
      (instructionsAssertions scope sharedConfig)
      (lib.mapAttrsToList (
          name: agent:
            assertExactlyOneTextSource "${scope} agent '${name}' prompt" agent.prompt
        )
        sharedConfig.agents)
      (lib.mapAttrsToList (
          name: command:
            assertExactlyOneTextSource "${scope} command '${name}' content" command.content
        )
        sharedConfig.commands)
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
        )
        sharedConfig.skills)
      (lib.mapAttrsToList (
          name: rule:
            assertExactlyOneTextSource "${scope} rule '${name}' content" rule.content
        )
        sharedConfig.rules)
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
          {
            assertion = server.type == "local" || server.cwd == null;
            message = "${scope} MCP server '${name}' sets cwd, which only a local server has";
          }
          {
            assertion = server.type == "remote" || (server.headersHelper == null && !(oauthSet server));
            message = "${scope} MCP server '${name}' sets headersHelper or oauth, which only a remote server has";
          }
        ])
        sharedConfig.mcpServers)
      (lib.mapAttrsToList (name: server: {
          assertion = !server.enabled || (server.command != null && server.extensionToLanguage != {});
          message = "${scope} LSP server '${name}' must define command and a non-empty extensionToLanguage unless enabled is false; Claude Code refuses to load a server without them";
        })
        sharedConfig.lspServers)
    ];
in {
  inherit collisionAssertions fieldTypeProblems includeCollisions typeProblems validateSharedConfig;
}
