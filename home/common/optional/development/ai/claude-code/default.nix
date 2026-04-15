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
    paths = [pkgs.claude-code-bin];
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

  programs.git.ignores = [
    ".playwright-mcp"
    ".claude/settings.local.json"
    ".claude/worktrees"
    "CLAUDE.local.md"
  ];

  programs.claude-code-profiles = {
    enable = true;
    enableZshIntegration = true;
    package = claudeWithPlugins;
    defaultProfile = "default";

    baseConfig = {
      pluginDirs = [
        "${pkgs.claude-code-plugins}/share/claude-code/plugins/ralph-wiggum"
      ];

      # Claude HUD config — "Full" preset, expanded layout
      extraFiles."plugins/claude-hud/config.json".source = jsonFormat.generate "claude-hud-config.json" {
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
          showConfigCounts = false;
          showDuration = true;
          showSpeed = false;
          showTokenBreakdown = true;
          showUsage = true;
          usageBarEnabled = true;
          showTools = false;
          showAgents = true;
          showTodos = true;
          showSessionName = true;
          showClaudeCodeVersion = false;
          showMemoryUsage = false;
          autocompactBuffer = "enabled";
          usageThreshold = 0;
          sevenDayThreshold = 80;
          environmentThreshold = 0;
          customLine = let
            apple = ""; # U+F179 — Nerd Font Apple icon
            nixos = ""; # U+F313 — Nerd Font NixOS icon
            osIcon =
              if config.hostSpec.isDarwin
              then apple
              else nixos;
          in "${osIcon} ${config.hostSpec.hostName}";
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
          custom = "brightCyan";
        };
      };

      settings = {
        env = {
          DISABLE_ERROR_REPORTING = "1";
          DISABLE_BUG_COMMAND = "1";
          CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
        };
        includeCoAuthoredBy = false;
        permissions = {
          allow = ["Bash(git diff:*)" "Bash(nix build:*)" "Bash(nix flake:*)" "Edit" "mcp__context7__resolve-library-id" "mcp__context7__query-docs"];
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
        (addon ./addons/spec-driven-dev)
      ];

      grafana = merge [
        {
          description = "Default with Grafana";
          settings.permissions.allow = [
            # Search
            "mcp__mcp-grafana__search_dashboards"
            "mcp__mcp-grafana__search_folders"
            # Dashboard (read)
            "mcp__mcp-grafana__get_dashboard_by_uid"
            "mcp__mcp-grafana__get_dashboard_summary"
            "mcp__mcp-grafana__get_dashboard_property"
            "mcp__mcp-grafana__get_dashboard_panel_queries"
            # Datasources
            "mcp__mcp-grafana__list_datasources"
            "mcp__mcp-grafana__get_datasource"
            # Prometheus
            "mcp__mcp-grafana__query_prometheus"
            "mcp__mcp-grafana__query_prometheus_histogram"
            "mcp__mcp-grafana__list_prometheus_metric_metadata"
            "mcp__mcp-grafana__list_prometheus_metric_names"
            "mcp__mcp-grafana__list_prometheus_label_names"
            "mcp__mcp-grafana__list_prometheus_label_values"
            # Loki
            "mcp__mcp-grafana__query_loki_logs"
            "mcp__mcp-grafana__query_loki_stats"
            "mcp__mcp-grafana__query_loki_patterns"
            "mcp__mcp-grafana__list_loki_label_names"
            "mcp__mcp-grafana__list_loki_label_values"
            # Incident
            "mcp__mcp-grafana__list_incidents"
            "mcp__mcp-grafana__get_incident"
            # OnCall
            "mcp__mcp-grafana__list_oncall_schedules"
            "mcp__mcp-grafana__get_oncall_shift"
            "mcp__mcp-grafana__get_current_oncall_users"
            "mcp__mcp-grafana__list_oncall_teams"
            "mcp__mcp-grafana__list_oncall_users"
            "mcp__mcp-grafana__list_alert_groups"
            "mcp__mcp-grafana__get_alert_group"
            # Sift
            "mcp__mcp-grafana__get_sift_investigation"
            "mcp__mcp-grafana__get_sift_analysis"
            "mcp__mcp-grafana__list_sift_investigations"
            "mcp__mcp-grafana__find_error_pattern_logs"
            "mcp__mcp-grafana__find_slow_requests"
            # Pyroscope
            "mcp__mcp-grafana__list_pyroscope_label_names"
            "mcp__mcp-grafana__list_pyroscope_label_values"
            "mcp__mcp-grafana__list_pyroscope_profile_types"
            "mcp__mcp-grafana__fetch_pyroscope_profile"
            # Assertions
            "mcp__mcp-grafana__get_assertions"
            # Navigation
            "mcp__mcp-grafana__generate_deeplink"
            # Rendering
            "mcp__mcp-grafana__get_panel_image"
            # Annotations (read)
            "mcp__mcp-grafana__get_annotations"
            "mcp__mcp-grafana__get_annotation_tags"
          ];
        }
      ];

      playwright = merge [
        {
          description = "Default with Playwright browser automation";
          settings.permissions.allow = [
            "mcp__playwright__browser_navigate"
            "mcp__playwright__browser_go_back"
            "mcp__playwright__browser_go_forward"
            "mcp__playwright__browser_wait"
            "mcp__playwright__browser_press_key"
            "mcp__playwright__browser_snapshot"
            "mcp__playwright__browser_click"
            "mcp__playwright__browser_drag"
            "mcp__playwright__browser_hover"
            "mcp__playwright__browser_type"
            "mcp__playwright__browser_console_logs"
            "mcp__playwright__browser_screenshot"
          ];
        }
      ];

      ops = merge [
        {
          description = "Operations and monitoring";
          extends = "grafana";
        }
      ];

      google-workspace = merge [
        {
          description = "Default with Google Workspace (Gmail, Sheets, Drive, Calendar, Docs)";
          settings.permissions.allow = [
            # Gmail
            "mcp__google-workspace__gmail_search"
            "mcp__google-workspace__gmail_read"
            "mcp__google-workspace__gmail_list_labels"
            # Calendar
            "mcp__google-workspace__calendar_list"
            "mcp__google-workspace__calendar_get_events"
            # Drive
            "mcp__google-workspace__drive_search"
            "mcp__google-workspace__drive_read"
            "mcp__google-workspace__drive_list"
            # Sheets
            "mcp__google-workspace__sheets_read"
            "mcp__google-workspace__sheets_list"
            # Docs
            "mcp__google-workspace__docs_read"
          ];
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
