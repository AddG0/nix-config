{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (config.programs.code-assistant-profiles) addons;
  # jdtls derives its workspace from sha1(basename(cwd)), so a bare launch shares
  # nvim's Eclipse workspace and the two corrupt each other's index. Without the
  # lombok agent, generated members read as errors.
  jdtlsForClaude = pkgs.writeShellScriptBin "jdtls-claude" ''
    data="''${XDG_CACHE_HOME:-$HOME/.cache}/jdtls-claude/$(printf %s "$PWD" | ${pkgs.coreutils}/bin/sha1sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
    exec ${pkgs.jdt-language-server}/bin/jdtls -data "$data" \
      --jvm-arg=-javaagent:${pkgs.lombok.src} "$@"
  '';
in {
  imports = lib.flatten [
    (lib.custom.scanPaths ./addons)
    (map (f: "${inputs.ai-toolkit}/home/claude-code/addons/${f}") [
      "jira"
    ])
  ];

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
          command = lib.getExe jdtlsForClaude;
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
        code-comments
        commit-commands
        documentation
        architecture
        design-notes
        caveman
        tmux-dev
        jira
        crash-capture
        sqry
      ];

      skills."frontend-design" = lib.custom.ai.fromClaudeSkillDir {
        inherit pkgs;
        source = "${inputs.claude-code}/plugins/frontend-design/skills/frontend-design";
      };

      commands = {
        "fix-tests".content.source = ./commands/fix-tests.md;
        "explore-codebase".content.source = ./commands/explore-codebase.md;
      };

      agents = {
        "graphrag-specialist" = lib.custom.ai.fromClaudeAgent "${inputs.claude-code-skills-collection}/agents/graphrag-specialist.md";
        "deep-research-agent".prompt.source = ./agents/deep-research.md;
      };

      rules = {
        nix.content.text = ''
          Nix conventions:
          - Flakes only — no `nix-env`, `nix-channel`, or `nix-shell`
          - For ad-hoc tooling, use `nix shell` or `nix run`
          - Minimal function signatures — only params actually used
        '';

        investigation.content.text = ''
          Read-only diagnostics — `git log`/`diff`, `kubectl get`/`describe`/`logs`, `curl`, `nix eval` — are never risky, so run them without asking. When a check surfaces a problem, chase it to root cause instead of reporting status and asking whether to look into it. "Check it" means check and diagnose; asking twice means go deeper, not print the same output again.

          Ground causal claims in something you actually gathered — a command you ran, a file you read, docs you fetched. A hypothesis is worth less than the cheapest command that would disprove it, so run that command before you explain the theory or act on it, and don't edit code to fix a cause you haven't confirmed. Keep verified findings and guesses distinguishable, and treat "I don't know yet, here's what would settle it" as a complete answer. A confident wrong diagnosis costs far more to unwind than the check would have cost to run.
        '';

        repos.content.text = ''
          Repo layout — resolve paths yourself instead of asking where a repo is.

          - ghq root is `~/Projects/code`; clones sit at `<host>/<owner…>/<repo>`, with GitLab subgroups fully nested (`gitlab.com/ShipperHQ/shipperhq-ai/Apps/NewDashboard`).
          - `ghq list <substring>` finds a repo among ~360 clones; `-p` prints absolute paths, `-e` matches exactly. `ghq get <url|owner/repo>` clones a missing one.
          - Work clones sit under `gitlab.com/ShipperHQ/…`, but their stored remote is `git@gitlab-work:…` — an ssh alias, not a resolvable hostname. Derive web and clone URLs from the ghq path, or map the alias back to `gitlab.com`; `insteadOf` rewrites only at transport time, so the alias stays in `.git/config`.
          - Worktrees are siblings of their clone with a `--<branch>` suffix and show up in `ghq list`; `gwq list` shows only worktrees.
          - `~/nix-config` and `~/nix-secrets` live outside the ghq root.
        '';

        "multi-agent".content.text = ''
          `Agent` and `TaskCreate`/`TaskUpdate` are easy to conflate and their parameters are not interchangeable: `Agent` spawns a subagent and takes `prompt`/`subagent_type`, while the Task tools manage the visible task list and take `subject`/`description`. Mixing them fails validation.

          `Monitor` and `SendMessage` are the deferred tools that actually bite here — load the schema with `ToolSearch` before the first call rather than after the failure.
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
