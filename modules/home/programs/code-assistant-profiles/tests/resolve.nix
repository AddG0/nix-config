# resolve-profile: extends, include, merging and frontmatter normalization.
{
  baseResolver,
  claudeAgentWith,
  emptySpec,
  evalCodingConfig,
  evalTargets,
  expect,
  failedOf,
  fixtureBody,
  fixtureFile,
  frontmatter,
  hostStub,
  lib,
  libWithCustom,
  normalize,
  passthroughAgent,
  pkgs,
  profile,
  resolverFor,
  rule,
  skillEntry,
  sourceSpec,
  spec,
  tryMessage,
  validation,
  withInstructions,
  ...
}: let
  resolve = profiles: name: (resolverFor profiles).resolveProfile [] name profiles.${name};

  declaredOptionDocs = let
    options =
      (lib.evalModules {
        specialArgs.lib = libWithCustom;
        modules = [
          hostStub
          (lib.modules.importApply ../default.nix {customLib = libWithCustom.custom;})
          {_module.args = {inherit pkgs;};}
        ];
      }).options.programs.code-assistant-profiles;
  in
    map (option: option.name) (lib.optionAttrSetToDocList {inherit (options) addons baseConfig profiles;});

  extendsProfiles = {
    base = profile {rules.fromBase = rule "base rule";};
    child = profile {
      extends = "base";
      rules.fromChild = rule "child rule";
    };
  };

  cyclicProfiles = {
    a = profile {extends = "b";};
    b = profile {extends = "a";};
  };

  addonOne = {rules.shared = rule "from addon one";};
  addonTwo = {rules.shared = rule "from addon two";};

  includeProfiles = {
    later = profile {include = [addonOne addonTwo];};
    ownWins = profile {
      include = [addonOne];
      rules.shared = rule "from the profile";
    };
  };

  ruleTextOf = resolved: name: resolved.rules.${name}.content.text;

  inherit (baseResolver) mergeConfigs;
  modelInvocable = text: (normalize {skills.demo = skillEntry {prompt = spec text;};}).skills.demo.invocation.model;

  normalizedRule =
    (normalize {
      rules.demo =
        rule ""
        // {
          content = spec "---\ndescription: From frontmatter\npaths: a.ts, b.ts\n---\n\nBody.";
        };
    })
    .rules.demo;

  slashRule = (normalize {rules.demo = rule "/commit stages and commits";}).rules.demo;

  claudeOnlyOfAgent = text: extra:
    (normalize {
      agents.demo = claudeAgentWith {
        prompt = spec text;
        inherit extra;
      };
    }).agents.demo.extra.claude-code or {
    };
  claudeOnlyOfSkill = text: (normalize {skills.demo = skillEntry {prompt = spec text;};}).skills.demo.extra.claude-code or {};
  claudeOnlyOfCommand = text: (normalize {commands.demo = {content = spec text;} // lib.genAttrs ["description" "argumentHint" "model" "agent"] (_: null) // {allowedTools = [];};}).commands.demo.extra.claude-code or {};
  # Every inherited field is one the type would otherwise reset to its default.
  overriddenChild =
    (evalCodingConfig ({config, ...}: {
      programs.code-assistant-profiles = {
        baseConfig.mcpServers.fromBase = {
          command = "base-server";
          enabled = false;
        };
        addons.retitle.skills.manual.description = "Retitled by an addon";
        profiles = {
          default = {
            mcpServers.s = {
              command = "srv";
              enabled = false;
              args = ["a"];
            };
            agents.reviewer = {
              description = "Reviews";
              prompt.text = "review body";
              model = "opus";
            };
            skills.manual = {
              description = "Manual only";
              prompt.source = fixtureFile;
              invocation.model = false;
            };
            lspServers.l = {
              command = "lsp";
              extensionToLanguage.".l" = "l";
            };
            commands.ship = {
              description = "Ship it";
              content.source = fixtureFile;
            };
          };
          child = {
            extends = "default";
            include = [config.programs.code-assistant-profiles.addons.retitle];
            mcpServers.s.args = ["b"];
            mcpServers.fromBase.args = ["--child"];
            agents.reviewer.description = "Reviews harder";
            lspServers.l.args = ["--stdio"];
            commands.ship.content.text = "ship body";
          };
        };
      };
    }))
    .programs
    .code-assistant-profiles
    .resolved
    .child;

  liftedFrontmatter = evalTargets {
    agents.loud.prompt.text = "---\ndescription: d\ncolor: magenta\nmaxTurns: many\n---\n\nBody.";
    skills.eager.prompt.text = "---\ndescription: d\neffort: huge\n---\n\nBody.";
  };

  liftedMetadata =
    (evalTargets {
      skills.tagged = {
        prompt.text = "---\ndescription: d\nmetadata:\n  short-description: From frontmatter\n  owner: fm\n---\n\nBody.";
        metadata.owner = "nix";
      };
    })
    .programs
    .code-assistant-profiles
    .resolved
    .default
    .skills
    .tagged;

  # A readOnly `name` throws only once something reads the resolved value.
  namedProfile = evalTargets {
    agents.a = {prompt = spec "a";};
    commands.c = {content = spec "c";};
    rules.r = {content = spec "r";};
    skills.s = {prompt = spec "s";};
    mcpServers.m = {command = "m";};
    lspServers.l = {
      command = "l";
      extensionToLanguage.".l" = "l";
    };
  };

  resolvedNames = let
    p = namedProfile.programs.code-assistant-profiles.resolved.default;
  in
    map (field: (lib.head (lib.attrValues p.${field})).name)
    ["agents" "commands" "rules" "skills" "mcpServers" "lspServers"];
in ''
  ${expect "nested invocation frontmatter makes a skill manual-only" (modelInvocable "---\ndescription: d\ninvocation:\n  model: false\n---\n\nBody.") false}
  ${expect "disable-model-invocation frontmatter makes a skill manual-only" (modelInvocable "---\ndescription: d\ndisable-model-invocation: true\n---\n\nBody.") false}
  ${expect "a skill declaring nothing stays model-invocable" (modelInvocable "---\ndescription: d\n---\n\nBody.") true}
  ${expect "a child profile keeps its parent's rules" (ruleTextOf (resolve extendsProfiles "child") "fromBase") "base rule"}
  ${expect "a child profile keeps its own rules" (ruleTextOf (resolve extendsProfiles "child") "fromChild") "child rule"}
  ${expect "a recursive extends chain is rejected" (tryMessage (resolve cyclicProfiles "a")) "threw"}
  ${expect "the later include wins a collision" (ruleTextOf (resolve includeProfiles "later") "shared") "from addon two"}
  ${expect "profile-own content beats an include" (ruleTextOf (resolve includeProfiles "ownWins") "shared") "from the profile"}
  ${expect "colliding includes are reported by index" (lib.attrNames (validation.includeCollisions includeProfiles.later)) ["rules.shared"]}
  ${expect "a single include collides with nothing" (validation.includeCollisions includeProfiles.ownWins) {}}

  ${expect "a child that overrides only an MCP server's args keeps its parent's command and enabled = false" {inherit (overriddenChild.mcpServers.s) command enabled args;} {
    command = "srv";
    enabled = false;
    args = ["b"];
  }}
  ${expect "a profile that overrides only a baseConfig MCP server's args keeps its command and enabled = false" {inherit (overriddenChild.mcpServers.fromBase) command enabled args;} {
    command = "base-server";
    enabled = false;
    args = ["--child"];
  }}
  ${expect "a child that overrides only an agent's description keeps its parent's prompt and model" {inherit (overriddenChild.agents.reviewer) description model prompt;} {
    description = "Reviews harder";
    model = "opus";
    prompt = spec "review body";
  }}
  ${expect "an include that overrides only a skill's description keeps its parent's prompt and manual invocation" {inherit (overriddenChild.skills.manual) description prompt invocation;} {
    description = "Retitled by an addon";
    prompt = sourceSpec;
    invocation = {
      user = true;
      model = false;
    };
  }}
  ${expect "a child that overrides only an LSP server's args keeps its parent's command and extensions" {inherit (overriddenChild.lspServers.l) command extensionToLanguage args;} {
    command = "lsp";
    extensionToLanguage.".l" = "l";
    args = ["--stdio"];
  }}
  ${expect "a child's content text replaces its parent's content source rather than sitting beside it" overriddenChild.commands.ship.content (spec "ship body")}

  ${expect "description is lifted out of frontmatter" normalizedRule.description "From frontmatter"}
  ${expect "a comma list in frontmatter becomes a list" normalizedRule.paths ["a.ts" "b.ts"]}
  ${expect "the fence is stripped from the body" normalizedRule.content.text "\nBody."}
  ${expect "inline text opening with a slash stays literal" slashRule.content.text "/commit stages and commits"}
  ${expect "a frontmatter value outside its type fails with an assertion naming the entry, not a throw" (tryMessage (failedOf liftedFrontmatter)) "no throw"}
  ${expect "a frontmatter colour, effort or maxTurns outside its type is named in an assertion" (failedOf liftedFrontmatter) [
    "profile 'default' agent 'loud' color is \"magenta\", which is not null or one of \"blue\", \"cyan\", \"green\", \"orange\", \"pink\", \"purple\", \"red\", \"yellow\""
    "profile 'default' agent 'loud' maxTurns is \"many\", which is not null or signed integer"
    "profile 'default' skill 'eager' reasoningEffort is \"huge\", which is not null or one of \"minimal\", \"low\", \"medium\", \"high\", \"xhigh\", \"max\", \"ultra\""
  ]}
  ${expect "frontmatter metadata is lifted into the typed field, with the Nix value winning per key" liftedMetadata.metadata {
    short-description = "From frontmatter";
    owner = "nix";
  }}
  ${expect "lifted frontmatter metadata no longer passes through only to claude-code" (liftedMetadata.extra.claude-code ? metadata) false}
  ${expect "a quoted comma stays inside its flow-list item" (frontmatter.fromText "---\ntools: [Read, 'Bash(git add, commit)']\n---\n").typedAttrs.tools ["Read" "Bash(git add, commit)"]}
  ${expect "a quoted comma stays inside its item in a frontmatter string list" (normalize {rules.demo = rule "---\npaths: ['a,b.ts', c.ts]\n---\n\nBody.";}).rules.demo.paths ["a,b.ts" "c.ts"]}
  ${expect "an unmatched quote in a flow list throws" (tryMessage (frontmatter.fromText "---\ntools: [Read, 'Bash]\n---\n").typedAttrs.tools) "threw"}
  ${expect "an empty flow list normalizes to no items, not one empty item" (map frontmatter.normalizeStringList ["[]" "[ ]" " "]) [[] [] []]}
  ${expect "an empty frontmatter paths list leaves a rule unscoped" (normalize {rules.demo = rule "---\npaths: []\n---\n\nBody.";}).rules.demo.paths []}

  ${expect "two texts concatenate" (mergeConfigs (withInstructions (spec "base")) (withInstructions (spec "overlay"))).instructions {
    text = "base\n\noverlay";
    source = null;
  }}
  ${expect "a lone source stays a source" (mergeConfigs (withInstructions emptySpec) (withInstructions sourceSpec)).instructions sourceSpec}
  ${expect "text plus source materializes to text" (mergeConfigs (withInstructions (spec "base")) (withInstructions sourceSpec)).instructions {
    text = "base\n\n" + fixtureBody;
    source = null;
  }}

  ${expect "every entry name is readable after resolution" resolvedNames ["a" "c" "r" "s" "m" "l"]}
  ${expect "option docs list each declared entry kind's fields though entries merge untyped" (map (name: lib.elem "programs.code-assistant-profiles.${name}" declaredOptionDocs) ["baseConfig.skills.<name>.prompt.text" "addons.<name>.agents.<name>.color" "profiles.<name>.mcpServers.<name>.command" "profiles.<name>.lspServers.<name>.extensionToLanguage" "profiles.<name>.commands.<name>.subtask" "profiles.<name>.rules.<name>.paths"]) [true true true true true true]}
  ${expect "agent frontmatter keys the shared layer does not know reach claude-code typed as YAML reads them" (claudeOnlyOfAgent passthroughAgent {}) {
    memory = "project";
    background = true;
    quoted = "true";
    count = 3;
    tags = ["a" "b"];
  }}
  ${expect "an agent's own extra.claude-code wins over its frontmatter" (claudeOnlyOfAgent passthroughAgent {claude-code.memory = "user";}).memory "user"}
  ${expect "skill frontmatter the shared layer lifts does not pass through" (claudeOnlyOfSkill "---\ndescription: d\neffort: high\ninvocation:\n  model: false\nuser-invocable: false\n---\n\nBody.") {"user-invocable" = false;}}
  ${expect "command frontmatter the shared layer does not know reaches claude-code" (claudeOnlyOfCommand "---\ndescription: d\nargument-hint: x\ndisable-model-invocation: true\n---\n\nBody.") {"disable-model-invocation" = true;}}
  ${expect "frontmatter with only known keys adds no claude-code extra" (claudeOnlyOfAgent "---\nname: demo\ndescription: d\ntools: Read\n---\n\nBody." {}) {}}
''
