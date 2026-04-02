{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  jsonFormat = pkgs.formats.json {};
  claudeWithPlugins = pkgs.symlinkJoin {
    name = "claude-code-with-plugins";
    paths = [pkgs.claude-code];
    buildInputs = [pkgs.makeWrapper];
    postBuild = let
      telemetryEnabled = config.hostSpec.telemetry.enabled && config.hostSpec.telemetry.claude-code.enabled;
      # Set via wrapper, not settings.json env — telemetry init reads process env
      # before settings are loaded, so CLAUDE_CODE_ENABLE_TELEMETRY must be set early
      telemetryFlags = lib.optionalString telemetryEnabled ''
        --set CLAUDE_CODE_ENABLE_TELEMETRY 1 \
        --set OTEL_METRICS_EXPORTER otlp \
        --set OTEL_LOGS_EXPORTER otlp \
        --set OTEL_EXPORTER_OTLP_PROTOCOL grpc \
        --set OTEL_EXPORTER_OTLP_ENDPOINT http://localhost:4317 \
        --set OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE cumulative
      '';
    in ''
      wrapProgram $out/bin/claude \
        --prefix PATH : ${lib.makeBinPath ([pkgs.socat pkgs.sox] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.bubblewrap])} \
        ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux "--set ALSA_PLUGIN_DIR ${pkgs.pipewire}/lib/alsa-lib"} \
        ${telemetryFlags}
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
          lspServers = (acc.lspServers or {}) // (c.lspServers or {});
          agents = (acc.agents or {}) // (c.agents or {});
          commands = (acc.commands or {}) // (c.commands or {});
          hooks = (acc.hooks or {}) // (c.hooks or {});
          skills = (acc.skills or {}) // (c.skills or {});
          rules = (acc.rules or {}) // (c.rules or {});
          pluginDirs = (acc.pluginDirs or []) ++ (c.pluginDirs or []);
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

  programs.git.ignores = [
    ".playwright-mcp"
    ".claude/settings.local.json"
    "CLAUDE.local.md"
  ];

  # Claude HUD config — "Full" preset, expanded layout, no setup needed
  home.file.".claude/plugins/claude-hud/config.json".source = jsonFormat.generate "claude-hud-config.json" {
    lineLayout = "expanded";
    showSeparators = false;
    pathLevels = 1;
    gitStatus = {
      enabled = true;
      showDirty = true;
      showAheadBehind = true;
      showFileStats = false;
    };
    display = {
      showModel = true;
      showProject = true;
      showContextBar = true;
      contextValue = "both";
      showConfigCounts = true;
      showDuration = true;
      showSpeed = false;
      showTokenBreakdown = true;
      showUsage = true;
      usageBarEnabled = true;
      showTools = true;
      showAgents = true;
      showTodos = true;
      showSessionName = true;
      showClaudeCodeVersion = false;
      showMemoryUsage = false;
      autocompactBuffer = "enabled";
      usageThreshold = 0;
      sevenDayThreshold = 80;
      environmentThreshold = 0;
      customLine = "";
    };
    colors = {
      context = "green";
      usage = "brightBlue";
      warning = "yellow";
      usageWarning = "brightMagenta";
      critical = "red";
      model = "cyan";
      project = "yellow";
      git = "magenta";
      gitBranch = "cyan";
      label = "dim";
      custom = 208;
    };
  };

  programs.claude-code-profiles = {
    enable = true;
    enableZshIntegration = true;
    package = claudeWithPlugins;
    defaultProfile = "default";

    baseConfig = {
      pluginDirs = [
        "${pkgs.claude-code-plugins}/share/claude-code/plugins/ralph-wiggum"
      ];

      lspServers = {
        rust = {
          command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
          extensionToLanguage = {".rs" = "rust";};
        };
        typescript = {
          command = "${pkgs.nodePackages.typescript-language-server}/bin/typescript-language-server";
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

      memory.text = ''
        Proactively invoke available skills when relevant.
        Prefer `-C`/path args over `cd &&` (e.g. `git -C /path status`, `nix develop /path`).
      '';

      settings = {
        env = {
          DISABLE_ERROR_REPORTING = "1";
          DISABLE_BUG_COMMAND = "1";
          CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
        };
        includeCoAuthoredBy = false;
        permissions = {
          allow = ["Bash(git diff:*)" "Bash(nix build:*)" "Bash(nix flake:*)" "Edit"];
          ask = ["Bash(git push:*)" "Bash(kubectl get secret:*)"];
          defaultMode = "acceptEdits";
          deny = ["Read(./.env)" "Read(**/terraform.tfvars)"];
        };
        statusLine = {
          command = "${pkgs.nodejs}/bin/node ${pkgs.claude-hud}/share/claude-code/plugins/claude-hud/dist/index.js";
          padding = 0;
          type = "command";
        };
        theme = "dark";
        voiceEnabled = true;
      };
    };

    profiles = {
      default = merge [
        (addon ./addons/context7)
        (addon ./addons/code-review)
        (addon ./addons/commit-commands)
        (addon ./addons/architecture)
        (addon ./addons/documentation)
        (addon ./addons/nix)
        (addon ./addons/spec-driven-dev)
        {
          description = "Everyday development";
          skills = {
            "frontend-design" = "${pkgs.claude-code-plugins}/share/claude-code/plugins/frontend-design/skills/frontend-design";
          };

          commands = {
            "fix-tests" = ./commands/fix-tests.md;
            "explore-codebase" = ./commands/explore-codebase.md;
          };

          agents = {
            "graphrag-specialist" = builtins.readFile "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/agents/graphrag-specialist.md";
            "deep-research-agent" = ./agents/deep-research.md;
          };

          # TODO: Make this flakes-only but not for nix-shell shebang
          rules."nix" = ''
            Nix conventions:
            - Flakes only — no `nix-env`, `nix-channel`, or `nix-shell`
            - Minimal function signatures — only params actually used
          '';

          rules."multi-agent" = ''
            Multi-agent orchestration:
            - Batch ALL independent agent spawns in ONE message for parallel execution
            - Use `run_in_background: true` for all agent Task calls
            - After spawning agents, STOP — do not poll TaskOutput or check status
            - Trust agents to return results; review ALL results before proceeding
            - Batch independent file reads/writes/edits in one message
            - Batch independent Bash commands in one message
          '';
        }
      ];

      grafana = merge [
        (addon ./addons/grafana)
        {
          description = "Default with Grafana";
          extends = "default";
        }
      ];

      playwright = merge [
        (addon ./addons/browser-mcp)
        {
          description = "Default with Playwright browser automation";
          extends = "default";
        }
      ];

      ops = merge [
        (addon ./addons/grafana)
        {
          description = "Operations and monitoring";
          extends = "default";
          memory.text = "Focus on operations, monitoring, and incidents. Use PromQL for Prometheus and LogQL for Loki.";
        }
      ];

      google-workspace = merge [
        (addon ./addons/google-workspace)
        {
          description = "Default with Google Workspace (Gmail, Sheets, Drive, Calendar, Docs)";
          extends = "default";
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
