# The claude-code target's renders and evaluated fixtures, shared by its unit and files tests.
{
  harness,
  lib,
  pkgs,
}: let
  inherit (import ../../../tests/_fixtures.nix {inherit harness lib pkgs;}) claudeAgentWith codexHooked evalCodingConfig failedOf forced libWithCustom mcpEntry needleProblems noNeedleProblems normalize passthroughAgent profile rule skillEntry sourceSpec spec typed;

  claudeSettingsHooks = import ../../../../claude-code/settings-hooks.nix {
    inherit lib;
    inherit (libWithCustom.custom) mkHookSchema;
  };

  renderClaude = import ../render.nix {
    inherit claudeSettingsHooks pkgs;
    lib = libWithCustom;
    customLib = libWithCustom.custom;
  };

  toClaude = raw: renderClaude (typed raw);

  modelsOfEveryProvider = {
    agents =
      lib.mapAttrs (_: model: {
        prompt = spec "a";
        inherit model;
      }) {
        alias = "default";
        suffixed = "opus[1m]";
        full = "claude-opus-4-6";
        openai = "gpt-5";
        qualified = "ai-proxy/gpt-6-luna";
      };
    skills.openai = {
      prompt = spec "s";
      model = "gpt-5";
    };
    commands.openai = {
      content = spec "c";
      model = "o3";
    };
  };

  renderedPassthroughAgent = (toClaude (profile {inherit ((normalize {agents.demo = claudeAgentWith {prompt = spec passthroughAgent;};})) agents;})).agents.demo;

  claudeValidation = import ../validation.nix {inherit claudeSettingsHooks lib;};
  lspEntry = attrs:
    {
      command = "l";
      args = [];
      env = {};
      extensionToLanguage.".l" = "l";
      enabled = true;
      initializationOptions = {};
      extra = {};
    }
    // attrs;

  remoteWithAuth = mcpEntry {
    type = "remote";
    url = "https://mcp.example";
    headersHelper = "print-headers";
    toolTimeout = 30000;
    oauth = {
      clientId = "cid";
      callbackPort = 8080;
      scopes = ["read" "write"];
    };
  };

  claudeExtras = toClaude (profile {
    mcpServers = {
      remote = remoteWithAuth;
      off = mcpEntry {
        command = "off";
        enabled = false;
      };
      sse =
        remoteWithAuth
        // {
          extra.claude-code = {
            type = "sse";
            oauth.authServerMetadataUrl = "https://auth.example/meta";
          };
        };
    };
    lspServers = {
      l = lspEntry {initializationOptions.formatting = true;};
      off = lspEntry {enabled = false;};
    };
    agents.demo = claudeAgentWith {
      color = "cyan";
      extra.claude-code = {
        permissionMode = "plan";
        isolation = "worktree";
        tools = ["Grep"];
        hooks.PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "guard";
              }
            ];
          }
        ];
      };
    };
    commands.ship = {
      description = "Ship it";
      argumentHint = null;
      allowedTools = [];
      model = "opus";
      agent = "Explore";
      subtask = true;
      content = spec "ship body";
      extra.claude-code.effort = "high";
    };
    skills.licensed = skillEntry {
      description = "d";
      version = "1.2";
      license = "MIT";
      compatibility = "needs git";
      metadata.owner = "addg";
      prompt = spec "skill body";
      extra.claude-code.arguments = ["issue" "branch"];
    };
  });

  claudeRendered = toClaude {
    description = "";
    instructions = sourceSpec;
    mcpServers = {};
    lspServers = {};
    commands = {};
    skills.versioned = skillEntry {
      description = "d";
      version = "1.2";
      prompt = spec "skill body";
    };
    rules.plain = rule "plain body";
    agents.demo = claudeAgentWith {};
  };

  frontmatterHooks = toClaude (profile {
    agents.guarded = claudeAgentWith {
      extra.claude-code.hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "check";
              timeout = 5;
            }
          ];
        }
      ];
    };
    skills.formatted = skillEntry {
      description = "d";
      prompt = spec "skill body";
      extra.claude-code.hooks.PostToolUse = [
        {
          matcher = "Edit";
          hooks = [
            {
              type = "command";
              command = "fmt";
              once = true;
            }
          ];
        }
      ];
    };
  });
  misspelledAgentHook = (toClaude (profile {agents.bad = claudeAgentWith {extra.claude-code.hooks.PreToolUs = [];};})).agents.bad;
  hookMessages = claudeValidation.frontmatterHookProblems "profile 'p'" (typed {
    agents.a = {
      prompt = spec "x";
      extra.claude-code.hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "c";
              once = true;
            }
          ];
        }
      ];
    };
    skills.s = {
      prompt = spec "x";
      resourcesRoot = null;
      extra.claude-code.hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "c";
              once = true;
            }
          ];
        }
      ];
    };
  });

  claudeTargetConfig = evalCodingConfig {
    programs.code-assistant-profiles = {
      targets.claude-code.enable = true;
      profiles.default.rules.r.content.text = "rule body";
    };
  };

  claudeTargetHookProblems = evalCodingConfig {
    programs.code-assistant-profiles = {
      targets.claude-code.enable = true;
      profiles.default.agents.a = {
        prompt.text = "a";
        extra.claude-code.hooks.Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "c";
                once = true;
              }
            ];
          }
        ];
      };
    };
  };

  javaLike = toClaude (profile {lspServers.java = lspEntry {extra.claude-code.startupTimeout = 120000;};});

  ruleWithExtra = toClaude (profile {rules.plain = rule "plain body" // {extra.claude-code.globs = ["*.md"];};});
in {
  inherit claudeAgentWith claudeExtras claudeRendered claudeSettingsHooks claudeTargetConfig claudeTargetHookProblems claudeValidation codexHooked evalCodingConfig failedOf forced frontmatterHooks hookMessages javaLike libWithCustom lspEntry mcpEntry misspelledAgentHook modelsOfEveryProvider needleProblems noNeedleProblems normalize passthroughAgent profile remoteWithAuth renderClaude renderedPassthroughAgent rule ruleWithExtra skillEntry sourceSpec spec toClaude typed;
}
