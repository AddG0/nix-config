{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  addon = path: import path {inherit config lib pkgs;};
  merge = configs:
    lib.foldl (
      acc: c: let
        texts = lib.filter (t: t != null) [(acc.instructions.text or null) (c.instructions.text or null)];
      in {
        description = c.description or acc.description or "";
        extends = c.extends or acc.extends or null;
        instructions = {
          text =
            if texts != []
            then lib.concatStringsSep "\n\n" texts
            else null;
          source = c.instructions.source or acc.instructions.source or null;
        };
        mcpServers = lib.recursiveUpdate (acc.mcpServers or {}) (c.mcpServers or {});
        lspServers = lib.recursiveUpdate (acc.lspServers or {}) (c.lspServers or {});
        agents = lib.recursiveUpdate (acc.agents or {}) (c.agents or {});
        commands = lib.recursiveUpdate (acc.commands or {}) (c.commands or {});
        skills = lib.recursiveUpdate (acc.skills or {}) (c.skills or {});
        rules = lib.recursiveUpdate (acc.rules or {}) (c.rules or {});
      }
    ) {}
    configs;
in {
  sops.secrets = {
    context7.sopsFile = "${inputs.nix-secrets}/global/api-keys/context7.yaml";
  };

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

    profiles.default = merge [
      (addon ./addons/nix)
      (addon ./addons/context7)
      (addon ./addons/code-review)
      (addon ./addons/commit-commands)
      (addon ./addons/documentation)
      (addon ./addons/architecture)
      (addon ./addons/spec-driven-dev)
      {
        description = "Everyday development";

        skills = {
          "frontend-design" = lib.custom.ai.fromClaudeSkillDir {
            inherit pkgs;
            source = "${pkgs.claude-code-plugins}/share/claude-code/plugins/frontend-design/skills/frontend-design";
          };
        };

        commands = {
          "fix-tests" = {
            content.source = ./commands/fix-tests.md;
          };
          "explore-codebase" = {
            content.source = ./commands/explore-codebase.md;
          };
        };

        agents = {
          "graphrag-specialist" = lib.custom.ai.fromClaudeAgent "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/agents/graphrag-specialist.md";
          "deep-research-agent" = {
            prompt.source = ./agents/deep-research.md;
          };
        };

        rules = {
          nix.content.text = ''
            Nix conventions:
            - Flakes only — no `nix-env`, `nix-channel`, or `nix-shell`
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
      }
    ];

    profiles.google-workspace = merge [
      (addon ./addons/google-workspace)
      {
        description = "Default with Google Workspace (Gmail, Sheets, Drive, Calendar, Docs)";
        extends = "default";
      }
    ];

    profiles.grafana = merge [
      (addon ./addons/grafana)
      {
        description = "Default with Grafana";
        extends = "default";
      }
    ];

    profiles.ops = {
      description = "Operations and monitoring";
      extends = "grafana";
      instructions.text = "Focus on operations, monitoring, and incidents. Use PromQL for Prometheus and LogQL for Loki.";
    };

    profiles.playwright = merge [
      (addon ./addons/browser-mcp)
      {
        description = "Default with Playwright browser automation";
        extends = "default";
      }
    ];
  };
}
