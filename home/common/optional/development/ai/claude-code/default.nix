{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    ./addons/browser-mcp
    ./addons/grafana
    ./addons/code-review
    # ./addons/superpowers
    (map (f: "${inputs.ai-toolkit}/home/claude-code/addons/${f}") [
      "context7"
      "graphiti"
      "jira"
    ])
  ];

  programs.claude-code = {
    enable = true;
    # agents = {
    #   senior-code-reviewer = builtins.readFile ../agents/senior-code-reviewer.md;
    # };
    skills = {
      "changelog-generator" = ./skills/changelog-generator.md;
      "software-architecture" = builtins.readFile "${pkgs.context-engineering-kit}/share/claude-code/plugins/ddd/skills/software-architecture/SKILL.md";
    };
    settings = {
      # https://mynixos.com/home-manager/option/programs.claude-code.settings
      # Disable telemetry: https://code.claude.com/docs/en/data-usage
      env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
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
          "Bash(kubectl get secret:*)"
        ];
        defaultMode = "acceptEdits";
        deny = [
          "Read(./.env)"
          # "Read(./secrets/**)"
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
