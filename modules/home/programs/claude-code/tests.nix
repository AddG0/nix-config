# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  fakeClaude = pkgs.writeShellScriptBin "claude" ''
    if (( $# )); then
      printf '%s\n' "$@"
    fi
  '';
  proxySettings = pkgs.writeText "proxy-settings.json" ''{"apiKeyHelper":"proxy-token"}'';
  wrapper = command:
    (import ./wrapper-script.nix {
      baseDir = ".config/claude-code/profiles";
      inherit lib pkgs;
      resolvedProfiles.default = {};
      cfg = {
        captureNode = null;
        unsetEnv = [];
        extraPath = [];
        defaultProfile = "default";
        profiles.default = {};
        package = fakeClaude;
        conditionalSettings = {
          command = lib.getExe (pkgs.writeShellScriptBin "proxy-ready" command);
          file = proxySettings;
        };
      };
    }).wrapperScript;
  shadowedTool = pkgs.writeShellScriptBin "shadowed-tool" "";
  pathWrapper =
    (import ./wrapper-script.nix {
      baseDir = ".config/claude-code/profiles";
      inherit lib pkgs;
      resolvedProfiles.default = {};
      cfg = {
        captureNode = null;
        unsetEnv = [];
        extraPath = [shadowedTool];
        defaultProfile = "default";
        profiles.default = {};
        package = pkgs.writeShellScriptBin "claude" "command -v shadowed-tool";
        conditionalSettings = null;
      };
    }).wrapperScript;
  inherit
    (import ./resolve-profile.nix {
      inherit lib;
      cfg = {};
    })
    mergeConfigs
    ;
  settingsOf = base: overlay: (mergeConfigs {settings = base;} {settings = overlay;}).settings;

  # `nix flake check` hands perSystem a plain nixpkgs lib; the module reads lib.custom.
  libWithCustom =
    if lib ? custom
    then lib
    else lib.extend (final: _: {custom = import ../../../../lib {lib = final;};});

  claudeSettingsHooks = import ./settings-hooks.nix {
    inherit lib;
    inherit (libWithCustom.custom) mkHookSchema;
  };
  hostStub = {lib, ...}: {
    options = {
      home.file = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
      };
      home.packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
      };
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
      };
      programs.code-assistant-profiles = lib.mkOption {
        type = lib.types.attrs;
        default.enable = false;
      };
    };
  };

  evalClaude = modules:
    (lib.evalModules {
      specialArgs.lib = libWithCustom;
      modules =
        [
          hostStub
          (lib.modules.importApply ./default.nix {customLib = libWithCustom.custom;})
          {
            _module.args = {inherit pkgs;};
            programs.claude-code-profiles = {
              enable = true;
              package = fakeClaude;
            };
          }
        ]
        ++ modules;
    })
    .config;

  failedAssertions = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);

  group = matcher: handlers:
    {hooks = handlers;}
    // lib.optionalAttrs (matcher != null) {inherit matcher;};

  problemsOf = location: raw: claudeSettingsHooks.problems location (claudeSettingsHooks.typeHooks [] raw);

  rejects = raw: !(builtins.tryEval (builtins.deepSeq (claudeSettingsHooks.typeHooks [] raw) true)).success;

  lspProfileFiles =
    (evalClaude [
      {
        programs.claude-code-profiles.profiles.default.lspServers.rust = {
          command = "rust-analyzer";
          extensionToLanguage.".rs" = "rust";
        };
      }
    ]).home.file;

  # Pure, so a failure throws while the check evaluates.
  settingsHookFailures = lib.runTests {
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
      expr = rejects {
        PreToolUs = [
          (group "Bash" [
            {
              type = "command";
              command = "x";
            }
          ])
        ];
      };
      expected = true;
    };
    testAMisspelledHandlerFieldFailsEvaluation = {
      expr = rejects {
        PreToolUse = [
          (group "Bash" [
            {
              type = "command";
              comand = "x";
            }
          ])
        ];
      };
      expected = true;
    };
    testAnUnknownHandlerTypeFailsEvaluation = {
      expr = rejects {
        Stop = [
          (group null [
            {
              type = "script";
              command = "x";
            }
          ])
        ];
      };
      expected = true;
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
          programs.claude-code-profiles.profiles.work.settings.hooks.Stop = [
            (group null [
              {
                type = "http";
                command = "c";
              }
            ])
          ];
          programs.claude-code-profiles.defaultProfile = "work";
        }
      ]);
      expected = [
        "programs.claude-code-profiles profile 'work' settings.hooks: Stop[0].hooks[0] (type http) sets `command`, which only applies to command handlers"
        "programs.claude-code-profiles profile 'work' settings.hooks: Stop[0].hooks[0] (type http) is missing required `url`"
      ];
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
    testAProfileWithoutSettingsWritesNoSettingsFile = {
      expr = (evalClaude [{programs.claude-code-profiles.profiles.default = {};}]).home.file ? ".config/claude-code/profiles/default/settings.json";
      expected = false;
    };
  };
  hook = matcher: {
    inherit matcher;
    hooks = [{command = matcher;}];
  };

  # Pure, so a failure throws while the check evaluates.
  mergeFailures = lib.runTests {
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
  };
in
  lib.throwIf (mergeFailures != [])
  "claude-code settings merge tests failed:\n${lib.generators.toPretty {} mergeFailures}"
  lib.throwIf (settingsHookFailures != [])
  "claude-code settings hook tests failed:\n${lib.generators.toPretty {} settingsHookFailures}"
  pkgs.runCommand "claude-code-conditional-settings-test" {nativeBuildInputs = [pkgs.jq];} ''
    export HOME="$PWD/home"
    mkdir -p "$HOME/.config/claude-code/profiles/default"

    ${wrapper "exit 0"}/bin/claude >reachable
    grep -qx -- '--settings' reachable
    grep -qxF '{"apiKeyHelper":"proxy-token"}' reachable

    ${wrapper "exit 0"}/bin/claude --settings '{"showThinkingSummaries":true}' -p hi >merged
    if [ "$(grep -cx -- '--settings' merged)" != 1 ]; then
      echo "FAIL: caller --settings not merged into the session settings" >&2
      cat merged >&2
      exit 1
    fi
    grep -qxF '{"apiKeyHelper":"proxy-token","showThinkingSummaries":true}' merged
    grep -qx -- '-p' merged

    echo '{"model":"opus"}' >caller.json
    ${wrapper "exit 0"}/bin/claude --settings=caller.json >merged-file
    grep -qxF '{"apiKeyHelper":"proxy-token","model":"opus"}' merged-file

    if ${wrapper "exit 0"}/bin/claude --settings missing.json 2>missing-err; then
      echo "FAIL: unreadable caller --settings did not abort" >&2
      exit 1
    fi
    grep -qF 'cannot merge --settings missing.json' missing-err

    ${wrapper "exit 1"}/bin/claude --settings '{"showThinkingSummaries":true}' >passthrough
    grep -qxF '{"showThinkingSummaries":true}' passthrough

    ${wrapper "exit 1"}/bin/claude >unreachable
    if [ -s unreachable ]; then
      echo "FAIL: unreachable proxy still added session settings" >&2
      cat unreachable >&2
      exit 1
    fi

    ${pathWrapper}/bin/claude >shadowed
    grep -qxF '${shadowedTool}/bin/shadowed-tool' shadowed

    timeout 4s ${wrapper "sleep 6"}/bin/claude --version >version
    grep -qxF -- '--version' version

    jq -e '.name == "lsp"' ${lspProfileFiles.".config/claude-code/profiles/default/plugins/lsp/.claude-plugin/plugin.json".source} >/dev/null \
      || { echo "FAIL: the LSP plugin manifest does not name the plugin" >&2; exit 1; }

    touch "$out"
  ''
