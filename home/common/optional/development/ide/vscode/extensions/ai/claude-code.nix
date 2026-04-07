{pkgs, ...}: {
  extensions = [
    pkgs.stable.vscode-extensions.anthropic.claude-code
  ];
  userSettings = {
    # Use system claude binary (NixOS can't run bundled dynamically linked binary)
    "claudeCode.claudeProcessWrapper" = "${pkgs.claude-code}/bin/claude";

    # Open in sidebar (not as editor tab)
    "claudeCode.preferredLocation" = "sidebar";

    # Custom instructions file locations
    "chat.instructionsFilesLocations" = {
      ".claude/rules" = true;
      "~/.claude/rules" = true;
    };
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
