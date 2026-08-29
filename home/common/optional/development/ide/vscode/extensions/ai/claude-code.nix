{
  config,
  lib,
  pkgs,
  ...
}: let
  profiles = config.programs.claude-code-profiles;
  # Hosts that skip development/ai get the options but no profiles.
  activeProfileDir = profiles.profiles.${profiles.defaultProfile}.profileDir;
in {
  extensions = [
    pkgs.vscode-marketplace.anthropic.claude-code
  ];
  userSettings =
    {
      "claudeCode.preferredLocation" = "sidebar";

      # Not ~/.claude/rules: that is where a profile-less install would put them,
      # and it stays empty here. The relative entry is per-repo rules.
      "chat.instructionsFilesLocations" =
        {
          ".claude/rules" = true;
        }
        // lib.optionalAttrs profiles.enable {
          "${config.home.homeDirectory}/${activeProfileDir}/rules" = true;
        };
    }
    // lib.optionalAttrs profiles.enable {
      # The extension's bundled binary is dynamically linked and won't run on
      # NixOS. Points at the profile wrapper, not the bare CLI, so the extension
      # gets the same CLAUDE_CONFIG_DIR, MCP servers and plugins as the shell.
      "claudeCode.claudeProcessWrapper" = lib.getExe' profiles.wrapperPackage "claude";
    };
  keybindings = [
    {
      key = "shift+enter";
      command = "workbench.action.terminal.sendSequence";
      args.text = builtins.fromJSON ''"\u001b\r"'';
      when = "terminalFocus";
    }
  ];
}
