{pkgs, ...}: {
  home.packages = with pkgs; [
    # Development tools
    claude-code-router
    # claude-flow
    repomix
  ];

  programs.claude-code = {
    enable = true;
    agents = {
        senior-code-reviewer = builtins.readFile ./agents/senior-code-reviewer.md;
    };
    settings = {
      # https://mynixos.com/home-manager/option/programs.claude-code.settings
      includeCoAuthoredBy = false;
      permissions = {
        additionalDirectories = [
          "../docs/"
        ];
        allow = [
          "Bash(git diff:*)"
          "Edit"
        ];
        ask = [
          "Bash(git push:*)"
        ];
        defaultMode = "acceptEdits";
        deny = [
          "Read(./.env)"
          "Read(./secrets/**)"
        ];
      };
      statusLine = {
        command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
        padding = 0;
        type = "command";
      };
      theme = "dark";
    };
  };
}
