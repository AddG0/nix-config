{pkgs, ...}: {
  extensions = [
    # We need to leave these on release to make sure the version is compatible with the vscode package
    pkgs.vscode-marketplace-release.github.copilot # Provides inline coding suggestions as you type.
    pkgs.vscode-marketplace-release.github.copilot-chat # A companion extension that provides conversational AI assistance.
  ];
  userSettings = {
    "github.copilot.enable" = {
      "*" = true;
      "plaintext" = false;
      "markdown" = true;
      "scminput" = false;
    };

    # Custom instructions file locations
    "chat.instructionsFilesLocations" = {
      ".github/instructions" = true;
    };

    # Enable Claude skills from .claude/skills directories
    "chat.useClaudeSkills" = true;

    # Enable nested AGENTS.md files
    "chat.useNestedAgentsMdFiles" = true;

    # Terminal auto-approve rules (safe commands)
    "chat.tools.terminal.autoApprove" = {
      # Safe read-only commands
      "ls" = true;
      "cat" = true;
      "head" = true;
      "tail" = true;
      "grep" = true;
      "find" = true;
      "which" = true;
      "pwd" = true;
      "echo" = true;
      "env" = true;
      "whoami" = true;

      # Git read operations
      "git status" = true;
      "git log" = true;
      "git diff" = true;
      "git branch" = true;
      "git show" = true;

      # Nix commands
      "nix flake" = true;
      "nix eval" = true;
      "nix search" = true;

      # Package managers (read)
      "npm list" = true;
      "npm outdated" = true;

      # Dangerous commands - require approval
      "rm" = false;
      "sudo" = false;
      "chmod" = false;
      "chown" = false;
      "mv" = false;
    };

    # Keep default safety rules
    "chat.tools.terminal.ignoreDefaultAutoApproveRules" = false;
  };
}
