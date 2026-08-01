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

  validateSharedConfig = scope: sharedConfig:
    lib.flatten [
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
          promptText =
            if skill.prompt.text != null
            then skill.prompt.text
            else if skill.prompt.source != null
            then builtins.readFile skill.prompt.source
            else "";
          referencesSkillDir = lib.hasInfix "\${SKILL_DIR}" promptText;
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
  inherit assertExactlyOneTextSource validateSharedConfig;
}
