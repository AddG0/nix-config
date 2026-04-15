{
  cfg,
  lib,
}: let
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
        name: skill:
          assertExactlyOneTextSource "${scope} skill '${name}' prompt" skill.prompt
          ++ [
            {
              assertion = skill.resourcesRoot == null || !(builtins.pathExists (skill.resourcesRoot + "/SKILL.md"));
              message = "${scope} skill '${name}' resourcesRoot must not contain SKILL.md; SKILL.md is generated from skill metadata and prompt";
            }
            {
              assertion = skill.resourcesRoot == null || !(builtins.pathExists (skill.resourcesRoot + "/prompt.md"));
              message = "${scope} skill '${name}' resourcesRoot must not contain prompt.md; prompt must be provided via skill.prompt";
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
