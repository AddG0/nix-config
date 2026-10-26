# The claude-code module: settings hooks, settings merging, and which files each profile writes.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  fakeClaude = harness.stubs.claude;
  libWithCustom = harness.lib;
  inherit
    (import ../resolve-profile.nix {
      inherit lib;
      cfg = {};
    })
    mergeConfigs
    ;
  settingsOf = base: overlay: (mergeConfigs {settings = base;} {settings = overlay;}).settings;

  claudeSettingsHooks = import ../settings-hooks.nix {
    inherit lib;
    inherit (libWithCustom.custom) mkHookSchema;
  };

  evalClaude = modules:
    harness.eval ([
        (harness.module ../default.nix)
        {
          programs.claude-code-profiles = {
            enable = true;
            package = fakeClaude;
          };
        }
      ]
      ++ modules);

  failedAssertions = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);

  group = matcher: handlers:
    {hooks = handlers;}
    // lib.optionalAttrs (matcher != null) {inherit matcher;};

  problemsOf = location: raw: claudeSettingsHooks.problems location (claudeSettingsHooks.typeHooks [] raw);

  # Deep, so a refused hook surfaces under expectedError.
  typedHooks = raw: builtins.deepSeq (claudeSettingsHooks.typeHooks [] raw) raw;

  lspProfileFiles =
    (evalClaude [
      {
        programs.claude-code-profiles.profiles.default.lspServers.rust = {
          command = "rust-analyzer";
          extensionToLanguage.".rs" = "rust";
        };
      }
    ]).home.file;

  hook = matcher: {
    inherit matcher;
    hooks = [{command = matcher;}];
  };
  pluginCheck = cfg: import ../plugin-check.nix {inherit cfg lib pkgs;};
  nullClaude = pluginCheck {
    checkConfig = true;
    package = null;
  };
in {
  "test checkConfig with a null claude package fails evaluation, naming the plugin dir and the fix" = {
    expr = nullClaude.validate "/plugins/lsp";
    expectedError.type = "ThrownError";
    expectedError.msg = "checkConfig is on but programs\\.claude-code-profiles\\.package is null, so `claude plugin validate` cannot check /plugins/lsp; set package, or checkConfig = false";
  };
  "test checkConfig with a null claude package refuses a store plugin dir rather than loading it unchecked" = {
    expr = "${nullClaude.pluginDir (pkgs.writeTextDir "plugin/x" "x")}";
    expectedError.type = "ThrownError";
    expectedError.msg = "programs\\.claude-code-profiles\\.package is null";
  };
  "test checkConfig off loads a plugin dir unchecked without a claude package" = {
    expr = (pluginCheck {
      checkConfig = false;
      package = null;
    }).pluginDir "/plugins/lsp";
    expected = "/plugins/lsp";
  };
  testEveryDocumentedEventIsAcceptedAndRendered = {
    expr = lib.attrNames (claudeSettingsHooks.render (claudeSettingsHooks.typeHooks [] (lib.genAttrs claudeSettingsHooks.events (_: [
      (group null [
        {
          type = "agent";
          prompt = "p";
        }
      ])
    ]))));
    expected = lib.sort (a: b: a < b) [
      "SessionStart"
      "Setup"
      "UserPromptSubmit"
      "UserPromptExpansion"
      "PreToolUse"
      "PermissionRequest"
      "PermissionDenied"
      "PostToolUse"
      "PostToolUseFailure"
      "PostToolBatch"
      "Notification"
      "MessageDisplay"
      "SubagentStart"
      "SubagentStop"
      "TaskCreated"
      "TaskCompleted"
      "Stop"
      "StopFailure"
      "TeammateIdle"
      "InstructionsLoaded"
      "ConfigChange"
      "CwdChanged"
      "DirectoryAdded"
      "FileChanged"
      "WorktreeCreate"
      "WorktreeRemove"
      "PreCompact"
      "PostCompact"
      "PreModelSwitch"
      "PostModelSwitch"
      "Elicitation"
      "ElicitationResult"
      "SessionEnd"
    ];
  };
  testAMisspelledEventFailsEvaluation = {
    expr = typedHooks {
      PreToolUs = [
        (group "Bash" [
          {
            type = "command";
            command = "x";
          }
        ])
      ];
    };
    expectedError.type = "ThrownError";
    expectedError.msg = "hooks\\.PreToolUs' does not exist";
  };
  testAMisspelledHandlerFieldFailsEvaluation = {
    expr = typedHooks {
      PreToolUse = [
        (group "Bash" [
          {
            type = "command";
            comand = "x";
          }
        ])
      ];
    };
    expectedError.type = "ThrownError";
    expectedError.msg = "\\.comand' does not exist";
  };
  testAnUnknownHandlerTypeFailsEvaluation = {
    expr = typedHooks {
      Stop = [
        (group null [
          {
            type = "script";
            command = "x";
          }
        ])
      ];
    };
    expectedError.type = "ThrownError";
    expectedError.msg = "\\.type' is not of type `one of \"agent\", \"command\", \"http\", \"mcp_tool\", \"prompt\"";
  };
  testRenderingDropsUnsetFieldsButKeepsAnEmptyExecArgv = {
    expr = claudeSettingsHooks.render (claudeSettingsHooks.typeHooks [] {
      PostToolUse = [
        (group "Edit" [
          {
            type = "command";
            command = "fmt";
            args = [];
            onFailure = "block";
          }
        ])
      ];
    });
    expected.PostToolUse = [
      (group "Edit" [
        {
          type = "command";
          command = "fmt";
          args = [];
          onFailure = "block";
        }
      ])
    ];
  };
  testEveryHandlerTypeRendersItsOwnFields = {
    expr =
      (claudeSettingsHooks.render (claudeSettingsHooks.typeHooks [] {
        PreToolUse = [
          (group "Bash" [
            {
              type = "http";
              url = "http://localhost/h";
              headers.Authorization = "Bearer $T";
              allowedEnvVars = ["T"];
              timeout = 5;
            }
            {
              type = "mcp_tool";
              server = "s";
              tool = "scan";
              input.file_path = "\${tool_input.file_path}";
            }
            {
              type = "prompt";
              prompt = "judge $ARGUMENTS";
              model = "haiku";
              continueOnBlock = true;
            }
            {
              type = "agent";
              prompt = "verify";
              statusMessage = "checking";
            }
            {
              type = "command";
              command = "c";
              "if" = "Bash(git *)";
              async = true;
              asyncRewake = false;
              shell = "bash";
            }
          ])
        ];
      })).PreToolUse;
    expected = [
      (group "Bash" [
        {
          type = "http";
          url = "http://localhost/h";
          headers.Authorization = "Bearer $T";
          allowedEnvVars = ["T"];
          timeout = 5;
        }
        {
          type = "mcp_tool";
          server = "s";
          tool = "scan";
          input.file_path = "\${tool_input.file_path}";
        }
        {
          type = "prompt";
          prompt = "judge $ARGUMENTS";
          model = "haiku";
          continueOnBlock = true;
        }
        {
          type = "agent";
          prompt = "verify";
          statusMessage = "checking";
        }
        {
          type = "command";
          command = "c";
          "if" = "Bash(git *)";
          async = true;
          asyncRewake = false;
          shell = "bash";
        }
      ])
    ];
  };
  testAFieldOfAnotherHandlerTypeIsReported = {
    expr = problemsOf "settings" {
      PreToolUse = [
        (group "Bash" [
          {
            type = "command";
            command = "c";
            url = "http://x";
          }
        ])
      ];
    };
    expected = ["PreToolUse[0].hooks[0] (type command) sets `url`, which only applies to http handlers"];
  };
  testAHandlerMissingItsRequiredFieldIsReported = {
    expr = problemsOf "settings" {
      PreToolUse = [
        (group null [
          {
            type = "mcp_tool";
            server = "s";
          }
        ])
      ];
    };
    expected = ["PreToolUse[0].hooks[0] (type mcp_tool) is missing required `tool`"];
  };
  testIfOnANonToolEventIsReportedBecauseTheHandlerWouldNeverRun = {
    expr = problemsOf "settings" {
      SessionStart = [
        (group null [
          {
            type = "command";
            command = "c";
            "if" = "Bash(git *)";
          }
        ])
      ];
    };
    expected = ["SessionStart[0].hooks[0] (type command) sets `if`, which Claude Code evaluates only on PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, PermissionDenied; on SessionStart the handler would never run"];
  };
  testAMatcherOnAnEventWithoutMatcherSupportIsReported = {
    expr = problemsOf "settings" {
      Stop = [
        (group "Bash" [
          {
            type = "command";
            command = "c";
          }
        ])
      ];
    };
    expected = ["Stop[0] sets matcher 'Bash', but Stop has no matcher support, so Claude Code ignores it"];
  };
  testOnceIsReportedOutsideSkillFrontmatter = {
    expr = map (location:
      problemsOf location {
        Stop = [
          (group null [
            {
              type = "command";
              command = "c";
              once = true;
            }
          ])
        ];
      }) ["settings" "agent" "skill"];
    expected = [
      ["Stop[0].hooks[0] (type command) sets `once`, which Claude Code honours only in skill frontmatter"]
      ["Stop[0].hooks[0] (type command) sets `once`, which Claude Code honours only in skill frontmatter"]
      []
    ];
  };
  testABadSettingsHookInAnyProfileFailsAnAssertionNamingTheProfile = {
    expr = failedAssertions (evalClaude [
      {
        programs.claude-code-profiles.profiles.alt.settings.hooks.Stop = [
          (group null [
            {
              type = "http";
              command = "c";
            }
          ])
        ];
        programs.claude-code-profiles.defaultProfile = "alt";
      }
    ]);
    expected = [
      "programs.claude-code-profiles profile 'alt' settings.hooks: Stop[0].hooks[0] (type http) sets `command`, which only applies to command handlers"
      "programs.claude-code-profiles profile 'alt' settings.hooks: Stop[0].hooks[0] (type http) is missing required `url`"
    ];
  };
  testMemoryWithBothTextAndSourceAfterMergingFailsAnAssertionNamingTheProfile = {
    expr = failedAssertions (evalClaude [
      {
        programs.claude-code-profiles = {
          baseConfig.memory.text = "base";
          profiles.default.memory.source = ./unit.nix;
        };
      }
    ]);
    expected = ["programs.claude-code-profiles profile 'default' memory cannot define both text and source; CLAUDE.md would get both"];
  };
  testAProfileWithLanguageServersWritesAPluginManifestBesideThem = {
    expr = map (file: lspProfileFiles ? ".config/claude-code/profiles/default/plugins/lsp/${file}") [".lsp.json" ".claude-plugin/plugin.json"];
    expected = [true true];
  };
  testAProfileWithoutLanguageServersWritesNoLspPlugin = {
    expr = (evalClaude [{programs.claude-code-profiles.profiles.default = {};}]).home.file ? ".config/claude-code/profiles/default/plugins/lsp/.claude-plugin/plugin.json";
    expected = false;
  };
  testTheRenamedHooksOptionStillWritesHookScriptsFromEverySource = {
    expr = let
      files =
        (evalClaude [
          ({config, ...}: {
            programs.claude-code-profiles = {
              baseConfig.hooks.base = "b";
              addons.extra.hooks.addon = "a";
              profiles.default = {
                hooks.own = "o";
                include = [config.programs.claude-code-profiles.addons.extra];
              };
            };
          })
        ]).home.file;
    in
      map (name: files.".config/claude-code/profiles/default/hooks/${name}") ["base" "addon" "own"];
    expected = map (text: {
      inherit text;
      executable = true;
    }) ["b" "a" "o"];
  };
  testSettingsFileResolvesInsideItsOwnStoreDirectoryNotTheStoreRoot = {
    expr = dirOf (toString (evalClaude [{programs.claude-code-profiles.profiles.default.settings.theme = "dark";}]).home.file.".config/claude-code/profiles/default/settings.json".source) == builtins.storeDir;
    expected = false;
  };

  testAProfileWithoutSettingsWritesNoSettingsFile = {
    expr = (evalClaude [{programs.claude-code-profiles.profiles.default = {};}]).home.file ? ".config/claude-code/profiles/default/settings.json";
    expected = false;
  };

  testSettingsHooksForOneEventFromTwoSourcesBothSurvive = {
    expr = (settingsOf {hooks.PreToolUse = [(hook "Bash")];} {hooks.PreToolUse = [(hook "AskUserQuestion")];}).hooks.PreToolUse;
    expected = [(hook "Bash") (hook "AskUserQuestion")];
  };
  testPermissionListsFromTwoSourcesBothSurvive = {
    expr = (settingsOf {permissions.allow = ["Edit"];} {permissions.allow = ["Edit(docs/**)"];}).permissions.allow;
    expected = ["Edit" "Edit(docs/**)"];
  };
  testAnEntryBothSourcesDeclareIsKeptOnce = {
    expr = (settingsOf {permissions.deny = ["Read(./.env)"];} {permissions.deny = ["Read(./.env)"];}).permissions.deny;
    expected = ["Read(./.env)"];
  };
  testAScalarFromTheOverlayStillWins = {
    expr = (settingsOf {model = "a";} {model = "b";}).model;
    expected = "b";
  };
}
