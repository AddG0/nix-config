{
  codexHooks,
  lib,
}: {
  options.programs.code-assistant-profiles.targets = lib.mkOption {
    type = lib.types.submodule {
      options.codex = {
        hooks = lib.mkOption {
          type = codexHooks.hooksType;
          default = {};
          example = lib.literalExpression ''
            {
              PreToolUse = [
                {
                  matcher = "^Bash$";
                  hooks = [
                    {
                      type = "command";
                      command = "/usr/local/bin/codex-pre-tool-use";
                      timeout = 30;
                    }
                  ];
                }
              ];
            }
          '';
          description = ''
            Codex lifecycle hooks, written to {file}`CODEX_HOME/hooks.json`
            through {option}`programs.codex.hooks`. Every event takes a list of
            matcher groups; handlers are `command` or `mcp_tool`, checked
            against their type and event.

            These are global: every Codex profile runs them. Claude Code hooks,
            by contrast, are set per profile in
            {option}`programs.claude-code-profiles.profiles.<name>.settings.hooks`.
          '';
        };

        checkConfig = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether each agent role's TOML is loaded by {option}`programs.codex.package` while it builds, so a role Codex cannot read fails the build. Turn off where that package cannot run on the build platform.";
        };

        writtenSkillNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          internal = true;
          description = "Names of the skills, commands among them, that the codex target writes to {file}`~/.agents/skills`, which opencode scans too.";
        };
      };
    };
  };
}
