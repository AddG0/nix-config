{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.programs.code-assistant-profiles) addons;
in {
  imports = lib.custom.scanPaths ./addons;

  programs.code-assistant-profiles = {
    enable = true;
    defaultProfile = "default";

    baseConfig = {
      lspServers = {
        rust = {
          command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
          extensionToLanguage = {".rs" = "rust";};
        };
        typescript = {
          command = "${pkgs.typescript-language-server}/bin/typescript-language-server";
          args = ["--stdio"];
          extensionToLanguage = {
            ".ts" = "typescript";
            ".tsx" = "typescriptreact";
            ".js" = "javascript";
            ".jsx" = "javascriptreact";
            ".mts" = "typescript";
            ".cts" = "typescript";
            ".mjs" = "javascript";
            ".cjs" = "javascript";
          };
        };
        java = {
          command = "${pkgs.jdt-language-server}/bin/jdtls";
          extensionToLanguage = {".java" = "java";};
          startupTimeout = 120000;
        };
      };

      instructions.text = ''
        Proactively invoke available skills when relevant.
        Prefer `-C`/path args over `cd &&` (e.g. `git -C /path status`, `nix develop /path`).
      '';
    };

    profiles.default = {
      description = "Everyday development";
      include = with addons; [
        nix
        context7
        code-review
        commit-commands
        documentation
        architecture
        spec-driven-dev
        caveman
      ];

      skills."frontend-design" = lib.custom.ai.fromClaudeSkillDir {
        inherit pkgs;
        source = "${pkgs.claude-code-plugins}/share/claude-code/plugins/frontend-design/skills/frontend-design";
      };

      commands = {
        "fix-tests".content.source = ./commands/fix-tests.md;
        "explore-codebase".content.source = ./commands/explore-codebase.md;
      };

      agents = {
        "graphrag-specialist" = lib.custom.ai.fromClaudeAgent "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/agents/graphrag-specialist.md";
        "deep-research-agent".prompt.source = ./agents/deep-research.md;
      };

      rules = {
        nix.content.text = ''
          Nix conventions:
          - Flakes only — no `nix-env`, `nix-channel`, or `nix-shell`
          - For ad-hoc tooling, use `nix shell` or `nix run`
          - Minimal function signatures — only params actually used
        '';

        "multi-agent".content.text = ''
          Multi-agent orchestration:
          - Batch ALL independent agent spawns in ONE message for parallel execution
          - Use `run_in_background: true` for all agent Task calls
          - After spawning agents, STOP — do not poll TaskOutput or check status
          - Trust agents to return results; review ALL results before proceeding
          - Batch independent file reads/writes/edits in one message
          - Batch independent Bash commands in one message
        '';
      };
    };

    profiles.google-workspace = {
      description = "Default with Google Workspace (Gmail, Sheets, Drive, Calendar, Docs)";
      extends = "default";
      include = [addons.google-workspace];
    };

    profiles.grafana = {
      description = "Default with Grafana";
      extends = "default";
      include = [addons.grafana];
    };

    profiles.ops = {
      description = "Operations and monitoring";
      extends = "grafana";
      instructions.text = "Focus on operations, monitoring, and incidents. Use PromQL for Prometheus and LogQL for Loki.";
    };

    profiles.playwright = {
      description = "Default with Playwright browser automation";
      extends = "default";
      include = [addons.browser-mcp];
    };
  };
}
