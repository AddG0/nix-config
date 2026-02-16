{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  claudeWithPlugins = pkgs.symlinkJoin {
    name = "claude-code-with-plugins";
    paths = [pkgs.claude-code];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --append-flags "--plugin-dir ${pkgs.claude-code-plugins}/share/claude-code/plugins/ralph-wiggum" \
        --prefix PATH : ${lib.makeBinPath ([pkgs.socat] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.bubblewrap])}
    '';
  };

  addon = path: import path {inherit pkgs config lib;};

  merge = configs:
    lib.foldl (
      acc: c: let
        texts = lib.filter (t: t != null) [(acc.memory.text or null) (c.memory.text or null)];
      in
        {
          description = c.description or acc.description or "";
          extends = c.extends or acc.extends or null;
          settings = lib.recursiveUpdate (acc.settings or {}) (c.settings or {});
          mcpServers = (acc.mcpServers or {}) // (c.mcpServers or {});
          agents = (acc.agents or {}) // (c.agents or {});
          commands = (acc.commands or {}) // (c.commands or {});
          hooks = (acc.hooks or {}) // (c.hooks or {});
          skills = (acc.skills or {}) // (c.skills or {});
          rules = (acc.rules or {}) // (c.rules or {});
        }
        // lib.optionalAttrs (texts != []) {
          memory.text = lib.concatStringsSep "\n\n" texts;
        }
    ) {}
    configs;

  skillsCollection = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills";
  anthropicSkills = "${pkgs.anthropic-skills}/share/claude-code/plugins/anthropic-skills/skills";
  skillFactory = "${pkgs.claude-code-skill-factory}/share/claude-code/plugins/claude-code-skill-factory/.claude";
in {
  imports = lib.flatten [
    (map (f: "${inputs.ai-toolkit}/home/claude-code/addons/${f}") [
      "jira"
    ])
    inputs.ai-toolkit.homeModules.default
  ];

  sops.secrets = {
    context7.sopsFile = "${inputs.nix-secrets}/global/api-keys/context7.yaml";
  };

  programs.claude-code-profiles = {
    enable = true;
    enableZshIntegration = true;
    package = claudeWithPlugins;
    defaultProfile = "default";

    baseConfig = {
      memory.text = ''
        Proactively invoke available skills when relevant.
        Prefer `-C`/path args over `cd &&` (e.g. `git -C /path status`, `nix develop /path`).
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
          allow = ["Bash(git diff:*)" "Edit"];
          ask = ["Bash(git push:*)" "Bash(kubectl get secret:*)"];
          defaultMode = "acceptEdits";
          deny = ["Read(./.env)"];
        };
        statusLine = {
          command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
          padding = 0;
          type = "command";
        };
        theme = "dark";
      };
    };

    profiles = {
      default = merge [
        (addon ./addons/context7)
        (addon ./addons/code-review)
        (addon ./addons/commit-commands)
        (addon ./addons/nix)
        {
          description = "Everyday development";
          skills = {
            "changelog-generator" = ./skills/changelog-generator;
          };

          commands = {
            "fix-tests" = ./commands/fix-tests.md;
            "explore-codebase" = ./commands/explore-codebase.md;
          };

          rules."nix" = ''
            Nix conventions:
            - Flakes only — no `nix-env`, `nix-channel`, or `nix-shell`
            - Minimal function signatures — only params actually used
          '';
        }
      ];

      architect = {
        description = "Architecture and design";
        extends = "default";
        memory.text = "Focus on architecture, design patterns, and system structure.";
        agents."graphrag-specialist" = builtins.readFile "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/agents/graphrag_specialist.md";
        skills = {
          "software-architecture" = "${pkgs.context-engineering-kit}/share/claude-code/plugins/ddd/skills/software-architecture";
          "frontend-design" = "${pkgs.claude-code-plugins}/share/claude-code/plugins/frontend-design/skills/frontend-design";
          "decision-matrix" = "${skillsCollection}/decision-matrix";
          "design-of-experiments" = "${skillsCollection}/design-of-experiments";
          "forecast-premortem" = "${skillsCollection}/forecast-premortem";
          "role-switch" = "${skillsCollection}/role-switch";
        };
      };

      grafana = merge [
        (addon ./addons/grafana)
        {
          description = "Default with Grafana";
          extends = "default";
        }
      ];

      ops = merge [
        (addon ./addons/grafana)
        {
          description = "Operations and monitoring";
          extends = "default";
          memory.text = "Focus on operations, monitoring, and incidents. Use PromQL for Prometheus and LogQL for Loki.";
          skills = {
            "postmortem" = "${skillsCollection}/postmortem";
            "security-threat-model" = "${skillsCollection}/security-threat-model";
          };
        }
      ];

      claude-code-maker = {
        description = "Creating Claude Code skills, agents, and configs";
        extends = "default";
        skills = {
          "skill-creator" = "${anthropicSkills}/skill-creator";
        };
        agents = {
          "skills-guide" = builtins.readFile "${skillFactory}/agents/skills-guide.md";
          "agents-guide" = builtins.readFile "${skillFactory}/agents/agents-guide.md";
          "hooks-guide" = builtins.readFile "${skillFactory}/agents/hooks-guide.md";
        };
        commands = {
          "build" = "${skillFactory}/commands/build.md";
          "build-hook" = "${skillFactory}/commands/build-hook.md";
        };
      };
    };
  };
}
