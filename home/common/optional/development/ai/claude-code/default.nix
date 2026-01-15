{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  packageSkills = {
    # === Architecture & Design ===
    # DDD-focused architecture guidance
    "software-architecture" = "${pkgs.context-engineering-kit}/share/claude-code/plugins/ddd/skills/software-architecture";
    # Production-grade frontend interfaces with high design quality
    "frontend-design" = "${pkgs.claude-code-plugins}/share/claude-code/plugins/frontend-design/skills/frontend-design";

    # === Decision Analysis & Risk ===
    # Weighted criteria analysis for complex decisions
    "decision-matrix" = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills/decision-matrix";
    # Statistical experimental design (A/B tests, factorial)
    "design-of-experiments" = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills/design-of-experiments";
    # Proactive failure mode identification before launch
    "forecast-premortem" = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills/forecast-premortem";
    # Blameless incident analysis and learning extraction
    "postmortem" = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills/postmortem";
    # STRIDE-based security threat modeling
    "security-threat-model" = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills/security-threat-model";

    # === Meta & Creation ===
    # Create new Claude Code skills with proper structure
    "skill-creator" = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills/skill-creator";
    # Craft effective prompts using proven patterns
    "meta-prompt-engineering" = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills/meta-prompt-engineering";
    # Adopt different expert perspectives for analysis
    "role-switch" = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills/role-switch";
  };

  pluginDirs = [
    "${pkgs.claude-code-plugins}/share/claude-code/plugins/ralph-wiggum"
  ];

  # Generate --plugin-dir flags for each plugin
  pluginDirFlags = lib.concatMapStrings (dir: " --plugin-dir ${dir}") pluginDirs;

  # Wrap claude-code with plugin directories and sandbox dependencies
  claude = pkgs.symlinkJoin {
    name = "claude-code-with-plugins";
    paths = [pkgs.claude-code];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --append-flags "${pluginDirFlags}" \
        --prefix PATH : ${lib.makeBinPath [pkgs.socat pkgs.bubblewrap]}
    '';
  };
in {
  imports = lib.flatten [
    # ./addons/browser-mcp
    # ./addons/grafana
    ./addons/code-review
    ./addons/commit-commands
    # ./addons/superpowers
    (map (f: "${inputs.ai-toolkit}/home/claude-code/addons/${f}") [
      "context7"
      # "graphiti"
      # "context-tracking"
      "jira"
    ])
  ];

  programs.claude-code = {
    enable = true;
    package = claude;
    agents = {
      # Knowledge graph RAG specialist
      "graphrag-specialist" = builtins.readFile "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/agents/graphrag_specialist.md";
      # senior-code-reviewer = builtins.readFile ../agents/senior-code-reviewer.md;
    };
    skills = {
      "changelog-generator" = ./skills/changelog-generator;
    };
    commands = {
      "fix-tests" = ./commands/fix-tests.md;
      "explore-codebase" = ./commands/explore-codebase.md;
    };
    memory.text = ''
      Proactively invoke available skills when they match the task at hand. Check skill descriptions and use them without being asked.
    '';
    settings = {
      env =
        {
          DISABLE_ERROR_REPORTING = "1";
          DISABLE_BUG_COMMAND = "1";
        }
        // lib.optionalAttrs (config.hostSpec.telemetry.enabled && config.hostSpec.telemetry.claude-code.enabled) {
          CLAUDE_CODE_ENABLE_TELEMETRY = "1";
          OTEL_METRICS_EXPORTER = "otlp";
          OTEL_LOGS_EXPORTER = "otlp";
          OTEL_EXPORTER_OTLP_PROTOCOL = "grpc";
        };
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

  home.file =
    lib.mapAttrs' (
      name: source:
        lib.nameValuePair ".claude/skills/${name}" {
          inherit source;
          recursive = true;
        }
    )
    packageSkills;
}
