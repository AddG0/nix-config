# claude-hud as Claude Code's status line, with an extra segment another module may add, as the ai-usage plugin adds the session's pool.
{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: {
  options.claude-hud.extraCommand = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Shell command claude-hud runs on each status-line refresh, printing `{\"label\": …}` JSON for an extra segment.";
  };

  config.programs.claude-code-profiles.baseConfig.settings.statusLine = {
    # claude-hud runs the extra command through its own shell, so the command's quoting reaches it intact.
    command =
      "${pkgs.nodejs}/bin/node ${customPkgs.claude-hud}/share/claude-code/plugins/claude-hud/dist/index.js"
      + lib.optionalString (config.claude-hud.extraCommand != null) " --extra-cmd ${lib.escapeShellArg config.claude-hud.extraCommand}";
    padding = 0;
    type = "command";
  };
}
