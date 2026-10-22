# Validation: content specs, skill resources, LSP and MCP checks, and typing of unused layers.
{
  agentWithModel,
  emptySpec,
  evalCodingConfig,
  evalTargets,
  failedOf,
  fixtureFile,
  forced,
  lib,
  mcpEntry,
  messagesOf,
  pkgs,
  rule,
  skillResources,
  typed,
  validation,
  withInstructions,
  ...
}: let
  derivationRootWithSkillMd = pkgs.linkFarm "reserved-resources" [
    {
      name = "SKILL.md";
      path = ./fixtures/reserved/SKILL.md;
    }
  ];

  failures = root:
    map (a: a.message)
    (lib.filter (a: !a.assertion) (validation.validateSharedConfig "profile 'p'" (typed {
      skills.demo = {
        prompt = {
          text = "body";
          source = null;
        };
        resourcesRoot = root;
      };
    })));

  lspAssertions = lsp: map (a: a.message) (lib.filter (a: !a.assertion) (evalTargets {lspServers.l = lsp;}).assertions);

  unusedLayers = evalCodingConfig {
    programs.code-assistant-profiles = {
      baseConfig.agents.based = {
        prompt.text = "a";
        maxTurns = "many";
      };
      addons.unused = {
        skills.s = {
          prompt.text = "s";
          reasoningEffort = "huge";
        };
        mcpServers.m = {
          command = "m";
          tolTimeout = 5000;
          oauth.scopes = [1];
        };
      };
      profiles.default = {};
    };
  };

  shortToolTimeout = evalTargets {
    mcpServers.m = {
      command = "m";
      toolTimeout = 999;
    };
  };

  # codex and opencode are on in every fixture; each case says whether claude-code joins them.
  warningsWith = claude: profiles:
    (evalCodingConfig {
      programs.code-assistant-profiles = {
        targets.claude-code.enable = claude;
        inherit profiles;
      };
    }).warnings;
  agentWith = attrs: {agents.a = {prompt.text = "a";} // attrs;};

  targetNames = ["claude-code" "codex" "opencode"];

  freeformCounts = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.int;
    options.label = lib.mkOption {type = lib.types.str;};
  };
  stringOrLetters = lib.types.either lib.types.str (lib.types.listOf (lib.types.enum ["a" "b"]));
in {
  "test a freeform submodule's extra keys are checked against its freeform type, not reported as unknown" = {
    expr = validation.typeProblems freeformCounts [] {
      label = "l";
      kept = 3;
      wrong = "x";
    };
    expected = ["wrong is \"x\", which is not signed integer"];
  };
  "test an enum inside a list inside an either is checked" = {
    expr = validation.typeProblems stringOrLetters ["field"] ["a" "z"];
    expected = ["field is [\n  \"a\"\n  \"z\"\n], which is not ${stringOrLetters.description}"];
  };
  "test a lazyAttrsOf value is checked against its element type, named by key" = {
    expr = validation.typeProblems (lib.types.lazyAttrsOf lib.types.ints.positive) ["counts"] {
      good = 1;
      bad = 0;
    };
    expected = ["counts.bad is 0, which is not positive integer, meaning >0"];
  };
  "test a value its type accepts has no problems" = {
    expr = validation.typeProblems (lib.types.listOf (lib.types.enum ["a" "b"])) ["field"] ["a" "b"];
    expected = [];
  };
  "test a set field no enabled target reads is named in one warning for every profile carrying it" = {
    expr = warningsWith true {
      default = agentWith {category = "review";};
      child = {
        extends = "default";
        instructions.text = "child";
      };
    };
    expected = ["programs.code-assistant-profiles.profiles \"child\", \"default\": no enabled target (claude-code, codex, opencode) reads these set fields, so they have no effect: agents.a.category"];
  };
  "test a field only a disabled target reads is named in a warning" = {
    expr = warningsWith false {default = agentWith {skills = ["s"];};};
    expected = ["programs.code-assistant-profiles.profiles \"default\": no enabled target (codex, opencode) reads these set fields, so they have no effect: agents.a.skills"];
  };
  "test a field one enabled target reads raises no warning, though another drops it" = {
    expr = warningsWith true {default = agentWith {skills = ["s"];};};
    expected = [];
  };
  "test a target's reads table naming a field no entry type has fails evaluation" = {
    expr = forced ((import ../content.nix {inherit lib;}).droppedFields {agents.colour = _: true;} (typed {}));
    expectedError.type = "ThrownError";
    expectedError.msg = "names fields its entry types lack: agents\\.colour";
  };
  "test a target's reads table naming real fields evaluates" = {
    expr = builtins.deepSeq ((import ../content.nix {inherit lib;}).droppedFields {agents."extra.codex" = _: true;} (typed {})) true;
    expected = true;
  };
  "test a model no target routes is named, with every profile carrying it, instead of the unread-field warning" = {
    expr = lib.filter (warning: lib.hasInfix "no target routes" warning || lib.hasInfix "no enabled target" warning) (warningsWith true {
      default = agentWith {model = "gemini-9";};
      child = {
        extends = "default";
        skills.s = {
          prompt.text = "s";
          model = "gemini-9";
        };
      };
    });
    expected = [
      "programs.code-assistant-profiles.profiles \"child\", \"default\": agents.a.model = \"gemini-9\" names a model no target routes (models.nix: Claude aliases and claude-* ids for claude-code, bare OpenAI ids for codex, provider/model ids for opencode), so every target drops it"
      "programs.code-assistant-profiles.profiles \"child\": skills.s.model = \"gemini-9\" names a model no target routes (models.nix: Claude aliases and claude-* ids for claude-code, bare OpenAI ids for codex, provider/model ids for opencode), so every target drops it"
    ];
  };
  "test a model one enabled target routes raises no warning" = {
    expr = warningsWith false {default = agentWith {model = "gpt-5";};};
    expected = [];
  };
  "test a field at its default raises no warning" = {
    expr = warningsWith false {default = agentWith {category = null;};};
    expected = [];
  };
  "test source dir with SKILL.md is rejected at eval" = {
    expr = failures ./fixtures/reserved;
    expected = [
      "profile 'p' skill 'demo' resourcesRoot must not contain SKILL.md; SKILL.md is generated from skill metadata and prompt"
    ];
  };
  "test clean source dir passes eval" = {
    expr = failures ./fixtures/clean;
    expected = [];
  };
  "test derivation root is not probed at eval" = {
    expr = failures derivationRootWithSkillMd;
    expected = [];
  };
  "test source dir is inspectable" = {
    expr = skillResources.inspectableAtEval ./fixtures/clean;
    expected = true;
  };
  "test derivation is not inspectable" = {
    expr = skillResources.inspectableAtEval derivationRootWithSkillMd;
    expected = false;
  };
  "test an empty content spec is named, not thrown on" = {
    expr = builtins.deepSeq (messagesOf {rules.demo = rule "" // {content = emptySpec;};}) true;
    expected = true;
  };
  "test an empty content spec reports which rule" = {
    expr = messagesOf {rules.demo = rule "" // {content = emptySpec;};};
    expected = ["profile 'p' rule 'demo' content must define either text or source"];
  };
  "test instructions cannot set both text and source" = {
    expr = messagesOf (withInstructions {
      text = "inline";
      source = fixtureFile;
    });
    expected = ["profile 'p' instructions cannot define both text and source"];
  };
  "test empty instructions are allowed" = {
    expr = messagesOf (withInstructions emptySpec);
    expected = [];
  };
  "test an LSP server without extensions is rejected" = {
    expr = lspAssertions {command = "l";};
    expected = [
      "profile 'default' LSP server 'l' must define command and a non-empty extensionToLanguage unless enabled is false; Claude Code refuses to load a server without them"
    ];
  };
  "test an LSP server without a command is rejected while enabled" = {
    expr = lib.length (lspAssertions {extensionToLanguage.".l" = "l";});
    expected = 1;
  };
  "test a disabled LSP server needs neither command nor extensions" = {
    expr = lspAssertions {enabled = false;};
    expected = [];
  };
  "test a color outside Claude's set is rejected" = {
    expr = forced (evalTargets {agents.a = (agentWithModel null) // {color = "teal";};}).programs.opencode.agents;
    expectedError.type = "ThrownError";
    expectedError.msg = "agents\\.a\\.color' is not of type";
  };
  "test a remote MCP server with a cwd is rejected" = {
    expr = messagesOf {
      mcpServers.r = mcpEntry {
        type = "remote";
        url = "https://mcp.example";
        cwd = "/srv";
      };
    };
    expected = ["profile 'p' MCP server 'r' sets cwd, which only a local server has"];
  };
  "test a local MCP server with oauth is rejected" = {
    expr = messagesOf {
      mcpServers.l = mcpEntry {
        command = "l";
        oauth.clientId = "cid";
      };
    };
    expected = ["profile 'p' MCP server 'l' sets headersHelper or oauth, which only a remote server has"];
  };
  "test an addon no profile includes and a baseConfig entry are typed on their own, naming where each was declared" = {
    expr = failedOf unusedLayers;
    expected = [
      "profile 'default' agent 'based' maxTurns is \"many\", which is not null or signed integer"
      "baseConfig agent 'based' maxTurns is \"many\", which is not null or signed integer"
      "addon 'unused' MCP server 'm' oauth.scopes[0] is 1, which is not string"
      "addon 'unused' MCP server 'm' sets `tolTimeout`, which is not an option"
      "addon 'unused' skill 's' reasoningEffort is \"huge\", which is not null or one of \"minimal\", \"low\", \"medium\", \"high\", \"xhigh\", \"max\", \"ultra\""
    ];
  };
  "test a badly typed profile field is an assertion under each target alone, for the default and any other profile" = {
    expr = lib.genAttrs targetNames (target:
      lib.filter (lib.hasInfix "maxTurns") (forced (failedOf (evalCodingConfig {
        programs.code-assistant-profiles = {
          targets = lib.genAttrs targetNames (name: {enable = lib.mkForce (name == target);});
          profiles.default.agents.a = {
            prompt.text = "a";
            maxTurns = "many";
          };
          profiles.other.agents.b = {
            prompt.text = "b";
            maxTurns = "few";
          };
        };
      }))));
    expected = lib.genAttrs targetNames (_: [
      "profile 'default' agent 'a' maxTurns is \"many\", which is not null or signed integer"
      "profile 'other' agent 'b' maxTurns is \"few\", which is not null or signed integer"
    ]);
  };
  "test a bad entry in an unused addon is an assertion, not a throw" = {
    expr = builtins.deepSeq (failedOf unusedLayers) true;
    expected = true;
  };
  "test an MCP tool timeout below 1000 ms is rejected" = {
    expr = failedOf shortToolTimeout;
    expected = ["profile 'default' MCP server 'm' toolTimeout is 999, which is not null or integer of at least 1000"];
  };
}
