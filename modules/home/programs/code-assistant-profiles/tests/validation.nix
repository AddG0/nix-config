# Validation: content specs, skill resources, LSP and MCP checks, and typing of unused layers.
{
  agentWithModel,
  emptySpec,
  evalCodingConfig,
  evalTargets,
  expect,
  failedOf,
  fixtureFile,
  lib,
  mcpEntry,
  messagesOf,
  pkgs,
  rule,
  skillResources,
  tryMessage,
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

  guard = skillResources.rejectReserved "codex" "demo";

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
in ''
  ${expect "a set field no enabled target reads is named in one warning for every profile carrying it" (warningsWith true {
    default = agentWith {category = "review";};
    child = {
      extends = "default";
      instructions.text = "child";
    };
  }) ["programs.code-assistant-profiles.profiles \"child\", \"default\": no enabled target (claude-code, codex, opencode) reads these set fields, so they have no effect: agents.a.category"]}
  ${expect "a field only a disabled target reads is named in a warning" (warningsWith false {default = agentWith {skills = ["s"];};}) ["programs.code-assistant-profiles.profiles \"default\": no enabled target (codex, opencode) reads these set fields, so they have no effect: agents.a.skills"]}
  ${expect "a field one enabled target reads raises no warning, though another drops it" (warningsWith true {default = agentWith {skills = ["s"];};}) []}
  ${expect "a target's reads table naming a field no entry type has fails evaluation" (tryMessage ((import ../content.nix {inherit lib;}).droppedFields {agents.colour = _: true;} (typed {}))) "threw"}
  ${expect "a target's reads table naming real fields evaluates" (tryMessage ((import ../content.nix {inherit lib;}).droppedFields {agents."extra.codex" = _: true;} (typed {}))) "no throw"}
  ${expect "a field at its default raises no warning" (warningsWith false {default = agentWith {category = null;};}) []}
  ${expect "source dir with SKILL.md is rejected at eval" (failures ./fixtures/reserved) [
    "profile 'p' skill 'demo' resourcesRoot must not contain SKILL.md; SKILL.md is generated from skill metadata and prompt"
  ]}
  ${expect "clean source dir passes eval" (failures ./fixtures/clean) []}
  ${expect "derivation root is not probed at eval" (failures derivationRootWithSkillMd) []}
  ${expect "source dir is inspectable" (skillResources.inspectableAtEval ./fixtures/clean) true}
  ${expect "derivation is not inspectable" (skillResources.inspectableAtEval derivationRootWithSkillMd) false}
  ${expect "an empty content spec is named, not thrown on" (tryMessage (messagesOf {rules.demo = rule "" // {content = emptySpec;};})) "no throw"}
  ${expect "an empty content spec reports which rule" (messagesOf {rules.demo = rule "" // {content = emptySpec;};}) ["profile 'p' rule 'demo' content must define either text or source"]}
  ${expect "instructions cannot set both text and source" (messagesOf (withInstructions {
    text = "inline";
    source = fixtureFile;
  })) ["profile 'p' instructions cannot define both text and source"]}
  ${expect "empty instructions are allowed" (messagesOf (withInstructions emptySpec)) []}

  ${expect "an LSP server without extensions is rejected" (lspAssertions {command = "l";}) [
    "profile 'default' LSP server 'l' must define command and a non-empty extensionToLanguage unless enabled is false; Claude Code refuses to load a server without them"
  ]}
  ${expect "an LSP server without a command is rejected while enabled" (lib.length (lspAssertions {extensionToLanguage.".l" = "l";})) 1}
  ${expect "a disabled LSP server needs neither command nor extensions" (lspAssertions {enabled = false;}) []}
  ${expect "a color outside Claude's set is rejected" (tryMessage (evalTargets {agents.a = (agentWithModel null) // {color = "teal";};}).programs.opencode.agents) "threw"}
  ${expect "a remote MCP server with a cwd is rejected" (messagesOf {
    mcpServers.r = mcpEntry {
      type = "remote";
      url = "https://mcp.example";
      cwd = "/srv";
    };
  }) ["profile 'p' MCP server 'r' sets cwd, which only a local server has"]}
  ${expect "a local MCP server with oauth is rejected" (messagesOf {
    mcpServers.l = mcpEntry {
      command = "l";
      oauth.clientId = "cid";
    };
  }) ["profile 'p' MCP server 'l' sets headersHelper or oauth, which only a remote server has"]}

  ${expect "an addon no profile includes and a baseConfig entry are typed on their own, naming where each was declared" (failedOf unusedLayers) [
    "profile 'default' agent 'based' maxTurns is \"many\", which is not null or signed integer"
    "baseConfig agent 'based' maxTurns is \"many\", which is not null or signed integer"
    "addon 'unused' MCP server 'm' oauth.scopes[0] is 1, which is not string"
    "addon 'unused' MCP server 'm' sets `tolTimeout`, which is not an option"
    "addon 'unused' skill 's' reasoningEffort is \"huge\", which is not null or one of \"minimal\", \"low\", \"medium\", \"high\", \"xhigh\", \"max\", \"ultra\""
  ]}
  ${expect "a bad entry in an unused addon is an assertion, not a throw" (tryMessage (failedOf unusedLayers)) "no throw"}
  ${expect "an MCP tool timeout below 1000 ms is rejected" (failedOf shortToolTimeout) ["profile 'default' MCP server 'm' toolTimeout is 999, which is not null or integer of at least 1000"]}
  mkdir -p reserved && touch reserved/SKILL.md
  if ( out="$PWD/reserved"; ${guard} ) 2>reserved.err; then
    echo "FAIL guard: accepted a resourcesRoot containing SKILL.md" >&2
    exit 1
  fi
  grep -q "codex skill 'demo' resourcesRoot must not contain SKILL.md" reserved.err || {
    echo "FAIL guard: wrong rejection message" >&2
    cat reserved.err >&2
    exit 1
  }

  mkdir -p clean && touch clean/reference.md
  if ! ( out="$PWD/clean"; ${guard} ) 2>clean.err; then
    echo "FAIL guard: rejected a clean resourcesRoot" >&2
    cat clean.err >&2
    exit 1
  fi

''
