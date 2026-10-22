# resolve-profile: extends, include, merging and frontmatter normalization.
{
  baseResolver,
  claudeAgentWith,
  emptySpec,
  evalCodingConfig,
  evalTargets,
  failedOf,
  fixtureBody,
  fixtureFile,
  forced,
  frontmatter,
  harness,
  hostStub,
  lib,
  normalize,
  passthroughAgent,
  profile,
  resolverFor,
  rule,
  skillEntry,
  sourceSpec,
  spec,
  validation,
  withInstructions,
  ...
}: let
  resolve = profiles: name: (resolverFor profiles).resolveProfile [] name profiles.${name};

  declaredOptionDocs = let
    options =
      (harness.evaluate [hostStub (harness.module ../default.nix)]).options.programs.code-assistant-profiles;
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
in {
  "test nested invocation frontmatter makes a skill manual-only" = {
    expr = modelInvocable "---\ndescription: d\ninvocation:\n  model: false\n---\n\nBody.";
    expected = false;
  };
  "test disable-model-invocation frontmatter makes a skill manual-only" = {
    expr = modelInvocable "---\ndescription: d\ndisable-model-invocation: true\n---\n\nBody.";
    expected = false;
  };
  "test a skill declaring nothing stays model-invocable" = {
    expr = modelInvocable "---\ndescription: d\n---\n\nBody.";
    expected = true;
  };
  "test a child profile keeps its parent's rules" = {
    expr = ruleTextOf (resolve extendsProfiles "child") "fromBase";
    expected = "base rule";
  };
  "test a child profile keeps its own rules" = {
    expr = ruleTextOf (resolve extendsProfiles "child") "fromChild";
    expected = "child rule";
  };
  "test a recursive extends chain is rejected" = {
    expr = forced (resolve cyclicProfiles "a");
    expectedError.type = "ThrownError";
    expectedError.msg = "has a recursive extends chain: a -> b -> a";
  };
  "test the later include wins a collision" = {
    expr = ruleTextOf (resolve includeProfiles "later") "shared";
    expected = "from addon two";
  };
  "test profile-own content beats an include" = {
    expr = ruleTextOf (resolve includeProfiles "ownWins") "shared";
    expected = "from the profile";
  };
  "test colliding includes are reported by index" = {
    expr = lib.attrNames (validation.includeCollisions includeProfiles.later);
    expected = ["rules.shared"];
  };
  "test a single include collides with nothing" = {
    expr = validation.includeCollisions includeProfiles.ownWins;
    expected = {};
  };
  "test a child that overrides only an MCP server's args keeps its parent's command and enabled = false" = {
    expr = {inherit (overriddenChild.mcpServers.s) command enabled args;};
    expected = {
      command = "srv";
      enabled = false;
      args = ["b"];
    };
  };
  "test a profile that overrides only a baseConfig MCP server's args keeps its command and enabled = false" = {
    expr = {inherit (overriddenChild.mcpServers.fromBase) command enabled args;};
    expected = {
      command = "base-server";
      enabled = false;
      args = ["--child"];
    };
  };
  "test a child that overrides only an agent's description keeps its parent's prompt and model" = {
    expr = {inherit (overriddenChild.agents.reviewer) description model prompt;};
    expected = {
      description = "Reviews harder";
      model = "opus";
      prompt = spec "review body";
    };
  };
  "test an include that overrides only a skill's description keeps its parent's prompt and manual invocation" = {
    expr = {inherit (overriddenChild.skills.manual) description prompt invocation;};
    expected = {
      description = "Retitled by an addon";
      prompt = sourceSpec;
      invocation = {
        user = true;
        model = false;
      };
    };
  };
  "test a child that overrides only an LSP server's args keeps its parent's command and extensions" = {
    expr = {inherit (overriddenChild.lspServers.l) command extensionToLanguage args;};
    expected = {
      command = "lsp";
      extensionToLanguage.".l" = "l";
      args = ["--stdio"];
    };
  };
  "test a child's content text replaces its parent's content source rather than sitting beside it" = {
    expr = overriddenChild.commands.ship.content;
    expected = spec "ship body";
  };
  "test description is lifted out of frontmatter" = {
    expr = normalizedRule.description;
    expected = "From frontmatter";
  };
  "test a comma list in frontmatter becomes a list" = {
    expr = normalizedRule.paths;
    expected = ["a.ts" "b.ts"];
  };
  "test the fence is stripped from the body" = {
    expr = normalizedRule.content.text;
    expected = "\nBody.";
  };
  "test inline text opening with a slash stays literal" = {
    expr = slashRule.content.text;
    expected = "/commit stages and commits";
  };
  "test a frontmatter value outside its type fails with an assertion naming the entry, not a throw" = {
    expr = builtins.deepSeq (failedOf liftedFrontmatter) true;
    expected = true;
  };
  "test a frontmatter colour, effort or maxTurns outside its type is named in an assertion" = {
    expr = failedOf liftedFrontmatter;
    expected = [
      "profile 'default' agent 'loud' color is \"magenta\", which is not null or one of \"blue\", \"cyan\", \"green\", \"orange\", \"pink\", \"purple\", \"red\", \"yellow\""
      "profile 'default' agent 'loud' maxTurns is \"many\", which is not null or signed integer"
      "profile 'default' skill 'eager' reasoningEffort is \"huge\", which is not null or one of \"minimal\", \"low\", \"medium\", \"high\", \"xhigh\", \"max\", \"ultra\""
    ];
  };
  "test frontmatter metadata is lifted into the typed field, with the Nix value winning per key" = {
    expr = liftedMetadata.metadata;
    expected = {
      short-description = "From frontmatter";
      owner = "nix";
    };
  };
  "test lifted frontmatter metadata no longer passes through only to claude-code" = {
    expr = liftedMetadata.extra.claude-code ? metadata;
    expected = false;
  };
  "test a quoted comma stays inside its flow-list item" = {
    expr = (frontmatter.fromText "---\ntools: [Read, 'Bash(git add, commit)']\n---\n").typedAttrs.tools;
    expected = ["Read" "Bash(git add, commit)"];
  };
  "test a quoted comma stays inside its item in a frontmatter string list" = {
    expr = (normalize {rules.demo = rule "---\npaths: ['a,b.ts', c.ts]\n---\n\nBody.";}).rules.demo.paths;
    expected = ["a,b.ts" "c.ts"];
  };
  "test an unmatched quote in a flow list throws" = {
    expr = forced (frontmatter.fromText "---\ntools: [Read, 'Bash]\n---\n").typedAttrs.tools;
    expectedError.type = "ThrownError";
    expectedError.msg = "unterminated flow list";
  };
  "test an empty flow list normalizes to no items, not one empty item" = {
    expr = map frontmatter.normalizeStringList ["[]" "[ ]" " "];
    expected = [[] [] []];
  };
  "test an empty frontmatter paths list leaves a rule unscoped" = {
    expr = (normalize {rules.demo = rule "---\npaths: []\n---\n\nBody.";}).rules.demo.paths;
    expected = [];
  };
  "test two texts concatenate" = {
    expr = (mergeConfigs (withInstructions (spec "base")) (withInstructions (spec "overlay"))).instructions;
    expected = {
      text = "base\n\noverlay";
      source = null;
    };
  };
  "test a lone source stays a source" = {
    expr = (mergeConfigs (withInstructions emptySpec) (withInstructions sourceSpec)).instructions;
    expected = sourceSpec;
  };
  "test text plus source materializes to text" = {
    expr = (mergeConfigs (withInstructions (spec "base")) (withInstructions sourceSpec)).instructions;
    expected = {
      text = "base\n\n" + fixtureBody;
      source = null;
    };
  };
  "test every entry name is readable after resolution" = {
    expr = resolvedNames;
    expected = ["a" "c" "r" "s" "m" "l"];
  };
  "test option docs list each declared entry kind's fields though entries merge untyped" = {
    expr = map (name: lib.elem "programs.code-assistant-profiles.${name}" declaredOptionDocs) ["baseConfig.skills.<name>.prompt.text" "addons.<name>.agents.<name>.color" "profiles.<name>.mcpServers.<name>.command" "profiles.<name>.lspServers.<name>.extensionToLanguage" "profiles.<name>.commands.<name>.subtask" "profiles.<name>.rules.<name>.paths"];
    expected = [true true true true true true];
  };
  "test agent frontmatter keys the shared layer does not know reach claude-code typed as YAML reads them" = {
    expr = claudeOnlyOfAgent passthroughAgent {};
    expected = {
      memory = "project";
      background = true;
      quoted = "true";
      count = 3;
      tags = ["a" "b"];
    };
  };
  "test an agent's own extra.claude-code wins over its frontmatter" = {
    expr = (claudeOnlyOfAgent passthroughAgent {claude-code.memory = "user";}).memory;
    expected = "user";
  };
  "test skill frontmatter the shared layer lifts does not pass through" = {
    expr = claudeOnlyOfSkill "---\ndescription: d\neffort: high\ninvocation:\n  model: false\nuser-invocable: false\n---\n\nBody.";
    expected = {"user-invocable" = false;};
  };
  "test command frontmatter the shared layer does not know reaches claude-code" = {
    expr = claudeOnlyOfCommand "---\ndescription: d\nargument-hint: x\ndisable-model-invocation: true\n---\n\nBody.";
    expected = {"disable-model-invocation" = true;};
  };
  "test frontmatter with only known keys adds no claude-code extra" = {
    expr = claudeOnlyOfAgent "---\nname: demo\ndescription: d\ntools: Read\n---\n\nBody." {};
    expected = {};
  };
}
