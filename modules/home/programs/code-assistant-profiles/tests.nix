# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  skillResources = import ./skill-resources.nix {inherit lib;};
  validation = import ./validation.nix {inherit lib;};

  launcherModule = import ./launcher.nix {inherit lib pkgs;};

  # `nix flake check` hands perSystem a plain nixpkgs lib, but the module tree
  # reads lib.custom the way host evaluation provides it.
  libWithCustom =
    if lib ? custom
    then lib
    else lib.extend (final: _: {custom = import ../../../../lib {lib = final;};});

  inherit (libWithCustom.custom) frontmatter;

  # resolveProfile reads sibling profiles off cfg, so each case supplies its own.
  resolverFor = profiles:
    import ./resolve-profile.nix {
      inherit frontmatter lib;
      cfg = {inherit profiles;};
    };

  emptySpec = {
    text = null;
    source = null;
  };

  spec = text: {
    inherit text;
    source = null;
  };

  # A profile as the module system would hand it over: every shared field present.
  profile = attrs:
    {
      description = "";
      extends = null;
      include = [];
      instructions = emptySpec;
      agents = {};
      commands = {};
      skills = {};
      rules = {};
      mcpServers = {};
      lspServers = {};
    }
    // attrs;

  rule = text: {
    name = "r";
    description = null;
    paths = [];
    content = spec text;
  };

  scopedRule = paths: text: (rule text) // {inherit paths;};

  resolve = profiles: name: (resolverFor profiles).resolveProfile [] name profiles.${name};

  tryMessage = value: let
    attempt = builtins.tryEval (builtins.deepSeq value "no throw");
  in
    if attempt.success
    then attempt.value
    else "threw";

  budget = {
    alwaysOn = {
      lines = 5;
      characters = 200;
    };
    description = {
      total = 100;
      characters = 40;
    };
    contextWindow = null;
    enforce = "warn";
  };

  noBudget = {
    alwaysOn = {
      lines = null;
      characters = null;
    };
    description = {
      total = null;
      characters = null;
    };
    contextWindow = null;
    enforce = "warn";
  };

  messagesOf = sharedConfig: map (a: a.message) (lib.filter (a: !a.assertion) (validation.validateSharedConfig "profile 'p'" sharedConfig));

  # Stubs make the generated invocation observable rather than inferred.
  stubAgent = name:
    pkgs.writeShellScriptBin name ''
      echo "BINARY=${name}"
      printf '%s\n' "$@"
    '';

  stubBin = pkgs.symlinkJoin {
    name = "agent-run-stubs";
    paths = map stubAgent ["claude" "codex" "opencode"];
  };

  mkLauncher = {
    agents,
    defaultAgent,
    skillNames ? ["diagnose-crash" "nix-build"],
  }:
    launcherModule.mkLauncher {
      inherit agents defaultAgent skillNames;
      profileBinDir = "/nonexistent/profile/bin";
    };

  allAgents = mkLauncher {
    agents = ["claude-code" "codex" "opencode"];
    defaultAgent = "claude-code";
  };

  noDefault = mkLauncher {
    agents = ["claude-code" "codex" "opencode"];
    defaultAgent = null;
  };

  claudeOnly = mkLauncher {
    agents = ["claude-code"];
    defaultAgent = "claude-code";
  };

  noSkills = mkLauncher {
    agents = ["claude-code"];
    defaultAgent = "claude-code";
    skillNames = [];
  };

  run = "${allAgents}/bin/agent-run";

  derivationRootWithSkillMd = pkgs.linkFarm "reserved-resources" [
    {
      name = "SKILL.md";
      path = ./test-fixtures/reserved/SKILL.md;
    }
  ];

  failures = root:
    map (a: a.message)
    (lib.filter (a: !a.assertion) (validation.validateSharedConfig "profile 'p'" {
      skills.demo = {
        prompt = {
          text = "body";
          source = null;
        };
        resourcesRoot = root;
      };
    }));

  expect = label: actual: expected:
    lib.optionalString (actual != expected) ''
      echo "FAIL ${label}: expected ${lib.generators.toPretty {} expected}, got ${lib.generators.toPretty {} actual}" >&2
      exit 1
    '';

  guard = skillResources.rejectReserved "codex" "demo";

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

  baseResolver = resolverFor {};
  inherit (baseResolver) mergeConfigs;
  normalize = baseResolver.normalizeSharedConfig;

  withInstructions = value: {instructions = value;};

  fixtureFile = ./test-fixtures/clean/reference.md;
  fixtureBody = builtins.readFile fixtureFile;

  sourceSpec = {
    text = null;
    source = fixtureFile;
  };

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

  budgetOf = b: sharedConfig: validation.budgetMessages "profile 'p'" b sharedConfig;

  derivedBudget = window: {
    alwaysOn = {
      lines = null;
      characters = null;
    };
    description = {
      total = null;
      characters = null;
    };
    contextWindow = window;
    enforce = "warn";
  };

  wordy = builtins.concatStringsSep "" (builtins.genList (_: "x") 60);

  selectionCases = {
    skills.chatty = {
      description = wordy;
      whenToUse = null;
    };
    skills.lean = {
      description = "Short and specific.";
      whenToUse = null;
    };
    agents.chatty.description = wordy;
  };

  overBudget = {
    instructions = emptySpec;
    rules.long = rule "one\ntwo\nthree\nfour\nfive\nsix\nseven";
  };

  scopedOnly = {
    instructions = emptySpec;
    rules.long = scopedRule ["**/*.ts"] "one\ntwo\nthree\nfour\nfive\nsix\nseven";
  };

  toClaude = import ./targets/claude-code.nix {
    inherit pkgs;
    lib = libWithCustom;
  };

  claudeRendered = toClaude {
    description = "";
    instructions = sourceSpec;
    mcpServers = {};
    lspServers = {};
    commands = {};
    skills = {};
    rules.plain = rule "plain body";
    agents.demo = {
      description = "A demo agent";
      prompt = spec "agent body";
      tools = ["Read"];
      disallowedTools = [];
      skills = [];
      model = null;
      color = null;
      category = null;
      reasoningEffort = "minimal";
      maxTurns = null;
    };
  };

  # The codex and opencode targets are modules, so they need a config to write
  # into. Only what they actually read is declared.
  hostStub = {lib, ...}: {
    options = {
      home.preferXdgDirectories = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      home.homeDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/t";
      };
      home.profileDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/t/.nix-profile";
      };
      home.file = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
      };
      home.packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
      };
      xdg.configHome = lib.mkOption {
        type = lib.types.str;
        default = "/home/t/.config";
      };
      xdg.configFile = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
      };
      programs.codex = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
      programs.opencode = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
      warnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
      };
    };
  };

  evalTargets = profileConfig:
    (lib.evalModules {
      modules = [
        hostStub
        ./default.nix
        {
          _module.args = {inherit pkgs;};
          _module.args.lib = libWithCustom;
          programs.code-assistant-profiles = {
            enable = true;
            targets.codex.enable = true;
            targets.opencode.enable = true;
            profiles.default = profileConfig;
          };
        }
      ];
    })
    .config;

  fromSource = evalTargets {instructions.source = fixtureFile;};

  # A readOnly `name` throws once resolution feeds the value back in, which stays
  # invisible until something reads it.
  namedProfile = evalTargets {
    agents.a = {prompt = spec "a";};
    commands.c = {content = spec "c";};
    rules.r = {content = spec "r";};
    skills.s = {prompt = spec "s";};
    mcpServers.m = {command = "m";};
    lspServers.l = {command = "l";};
  };

  resolvedNames = let
    p = namedProfile.programs.code-assistant-profiles.resolved.default;
  in
    map (field: (lib.head (lib.attrValues p.${field})).name)
    ["agents" "commands" "rules" "skills" "mcpServers" "lspServers"];
in
  pkgs.runCommand "code-assistant-profiles-test" {} ''
    ${expect "source dir with SKILL.md is rejected at eval" (failures ./test-fixtures/reserved) [
      "profile 'p' skill 'demo' resourcesRoot must not contain SKILL.md; SKILL.md is generated from skill metadata and prompt"
    ]}
    ${expect "clean source dir passes eval" (failures ./test-fixtures/clean) []}
    ${expect "derivation root is not probed at eval" (failures derivationRootWithSkillMd) []}
    ${expect "source dir is inspectable" (skillResources.inspectableAtEval ./test-fixtures/clean) true}
    ${expect "derivation is not inspectable" (skillResources.inspectableAtEval derivationRootWithSkillMd) false}

    # --- resolve-profile: extends and include ---
    ${expect "a child profile keeps its parent's rules" (ruleTextOf (resolve extendsProfiles "child") "fromBase") "base rule"}
    ${expect "a child profile keeps its own rules" (ruleTextOf (resolve extendsProfiles "child") "fromChild") "child rule"}
    ${expect "a recursive extends chain is rejected" (tryMessage (resolve cyclicProfiles "a")) "threw"}
    ${expect "the later include wins a collision" (ruleTextOf (resolve includeProfiles "later") "shared") "from addon two"}
    ${expect "profile-own content beats an include" (ruleTextOf (resolve includeProfiles "ownWins") "shared") "from the profile"}
    ${expect "colliding includes are reported by index" (lib.attrNames (validation.includeCollisions includeProfiles.later)) ["rules.shared"]}
    ${expect "a single include collides with nothing" (validation.includeCollisions includeProfiles.ownWins) {}}

    # --- resolve-profile: frontmatter normalization ---
    ${expect "description is lifted out of frontmatter" normalizedRule.description "From frontmatter"}
    ${expect "a comma list in frontmatter becomes a list" normalizedRule.paths ["a.ts" "b.ts"]}
    ${expect "the fence is stripped from the body" normalizedRule.content.text "\nBody."}
    ${expect "inline text opening with a slash stays literal" slashRule.content.text "/commit stages and commits"}

    # --- resolve-profile: instructions never carry text and source at once ---
    ${expect "two texts concatenate" (mergeConfigs (withInstructions (spec "base")) (withInstructions (spec "overlay"))).instructions {
      text = "base\n\noverlay";
      source = null;
    }}
    ${expect "a lone source stays a source" (mergeConfigs (withInstructions emptySpec) (withInstructions sourceSpec)).instructions sourceSpec}
    ${expect "text plus source materializes to text" (mergeConfigs (withInstructions (spec "base")) (withInstructions sourceSpec)).instructions {
      text = "base\n\n" + fixtureBody;
      source = null;
    }}

    ${expect "an empty content spec is named, not thrown on" (tryMessage (messagesOf {rules.demo = rule "" // {content = emptySpec;};})) "no throw"}
    ${expect "an empty content spec reports which rule" (messagesOf {rules.demo = rule "" // {content = emptySpec;};}) ["profile 'p' rule 'demo' content must define either text or source"]}
    ${expect "instructions cannot set both text and source" (messagesOf (withInstructions {
      text = "inline";
      source = fixtureFile;
    })) ["profile 'p' instructions cannot define both text and source"]}
    ${expect "empty instructions are allowed" (messagesOf (withInstructions emptySpec)) []}

    ${expect "an over-budget profile is reported once per breached limit" (lib.length (budgetOf budget overBudget)) 1}
    ${expect "the report names the rule to cut" (lib.hasInfix "long 7L" (lib.head (budgetOf budget overBudget))) true}
    ${expect "path-scoped rules are outside the budget" (budgetOf budget scopedOnly) []}
    ${expect "a null budget disables the check" (budgetOf noBudget overBudget) []}
    ${expect "instructions count toward the budget" (validation.measureAlwaysOn (withInstructions (spec "a\nb\nc"))).lines 3}
    ${expect "a breached total and a breached per-entry cap are reported separately" (lib.length (validation.selectionMessages "profile 'p'" budget.description selectionCases)) 2}
    ${expect "the total report counts every skill and agent" (lib.hasInfix "3 skills and agents carry 139 characters" (lib.head (validation.selectionMessages "profile 'p'" budget.description selectionCases))) true}
    ${expect "the truncation report names only the oversized entries" (lib.hasInfix "2 descriptions exceed" (lib.elemAt (validation.selectionMessages "profile 'p'" budget.description selectionCases) 1)) true}
    ${expect "the truncation report skips a lean description" (lib.hasInfix "lean" (lib.elemAt (validation.selectionMessages "profile 'p'" budget.description selectionCases) 1)) false}
    ${expect "whenToUse counts toward an entry's length" (map (e: e.length) (validation.selectionEntries {
      skills.pair = {
        description = "Twenty characters ok";
        whenToUse = "and another twenty-eight here";
      };
    })) [49]}
    ${expect "a null description budget disables both checks" (validation.selectionMessages "profile 'p'" {
        total = null;
        characters = null;
      }
      selectionCases) []}
    ${expect "the total budget derives from the context window" (validation.resolveBudgets (derivedBudget 200000)).description.total 8000}
    ${expect "a bigger window buys a bigger listing" (validation.resolveBudgets (derivedBudget 1000000)).description.total 40000}
    ${expect "an explicit total wins over the derivation" (validation.resolveBudgets (budget // {contextWindow = 1000000;})).description.total 100}
    ${expect "a null context window drops the derived budget" (validation.resolveBudgets (derivedBudget null)).description.total null}

    ${expect "claude-code passes an instructions source through unread" claudeRendered.memory sourceSpec}
    ${expect "claude-code drops the effort level it has no name for" (lib.hasInfix "effort" claudeRendered.agents.demo) false}
    ${expect "claude-code emits an agent's declared tools" (lib.hasInfix "  - 'Read'" claudeRendered.agents.demo) true}
    ${expect "a rule with no paths renders as its bare source" claudeRendered.rules.plain "plain body"}
    ${expect "codex inlines an instructions source" fromSource.programs.codex.context fixtureBody}
    ${expect "opencode inlines an instructions source" (lib.removeAttrs fromSource.programs.opencode.context ["_type" "priority"]).content fixtureBody}
    ${expect "every entity name is readable after resolution" resolvedNames ["a" "c" "r" "s" "m" "l"]}

    # --- build-time guard: same rule, enforced against the assembled dir ---
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

    # --- agent-run ---
    export PATH="${stubBin}/bin:$PATH"

    fail() {
      echo "FAIL agent-run: $1" >&2
      shift
      for f in "$@"; do
        echo "--- $f" >&2
        cat "$f" >&2
      done
      exit 1
    }

    ${run} --list-agents >listed
    printf 'claude-code\ncodex\nopencode\n' >expected-agents
    cmp -s listed expected-agents || fail "--list-agents did not list every enabled agent" listed

    ${claudeOnly}/bin/agent-run --list-agents >listed-one
    printf 'claude-code\n' >expected-one
    cmp -s listed-one expected-one || fail "a disabled target must not be offered" listed-one

    if ${claudeOnly}/bin/agent-run --agent codex 2>disabled.err; then
      fail "selecting a disabled agent should fail" disabled.err
    fi
    grep -q 'unknown agent: codex' disabled.err ||
      fail "wrong message for a disabled agent" disabled.err

    ${run} --prompt hello >claude.out
    grep -qx 'BINARY=claude' claude.out || fail "default agent was not claude" claude.out
    grep -qx -- '--permission-mode' claude.out || fail "claude lost its auto-approve flag" claude.out
    grep -qx 'bypassPermissions' claude.out || fail "claude lost its auto-approve value" claude.out
    grep -qx -- '--' claude.out || fail "claude prompt was not passed after a separator" claude.out
    grep -qx 'hello' claude.out || fail "claude never received the prompt" claude.out

    ${run} --agent opencode --prompt hello >opencode.out
    grep -qx -- '--auto' opencode.out || fail "opencode lost its auto-approve flag" opencode.out
    grep -qx -- '--prompt' opencode.out || fail "opencode prompt was not passed by flag" opencode.out
    if grep -qx -- '--' opencode.out; then
      fail "opencode must not receive a bare separator" opencode.out
    fi

    ${run} --agent codex --prompt hello >codex.out
    grep -qx -- '--dangerously-bypass-approvals-and-sandbox' codex.out ||
      fail "codex lost its auto-approve flag" codex.out

    ${run} --prompt hi -- --model opus >passthru.out
    model_line=$(grep -nx -- '--model' passthru.out | cut -d: -f1)
    sep_line=$(grep -nx -- '--' passthru.out | cut -d: -f1)
    [ -n "$model_line" ] && [ -n "$sep_line" ] && [ "$model_line" -lt "$sep_line" ] ||
      fail "passthrough args must precede the prompt separator" passthru.out

    ${run} --skill diagnose-crash >skill.out
    grep -q 'Use the diagnose-crash skill' skill.out || fail "skill was not named" skill.out

    ${run} --help >help.out
    while read -r flag; do
      grep -q -- "$flag" help.out || fail "--help does not document $flag" help.out
    done <<'FLAGS'
    --agent
    --prompt
    --skill
    --cwd
    --list-agents
    --list-skills
    FLAGS

    ${run} --prompt 'why did it die' --skill diagnose-crash >both.out
    grep -q 'why did it die' both.out || fail "prompt was dropped when a skill was given" both.out
    grep -q 'Use the diagnose-crash skill' both.out || fail "skill note was dropped" both.out

    if ${run} --skill nope 2>skill.err; then
      fail "an unknown skill should fail" skill.err
    fi
    grep -q 'unknown skill: nope' skill.err || fail "wrong message for unknown skill" skill.err
    grep -q 'diagnose-crash nix-build' skill.err ||
      fail "unknown skill error should list what is available" skill.err

    if ${noSkills}/bin/agent-run --skill nope 2>empty.err; then
      fail "a profile with no skills should still reject --skill" empty.err
    fi
    grep -q 'defines none' empty.err || fail "wrong message for a skill-less profile" empty.err

    if ${noDefault}/bin/agent-run --prompt x 2>default.err; then
      fail "no configured default should fail rather than guess" default.err
    fi
    grep -q 'no agent selected and no default configured' default.err ||
      fail "wrong message when no default is configured" default.err
    ${noDefault}/bin/agent-run --agent codex --prompt x >override.out ||
      fail "--agent should work with no default configured" override.out
    grep -qx 'BINARY=codex' override.out || fail "--agent override was ignored" override.out

    if ${run} --agent gemini 2>unknown.err; then
      fail "an unknown agent should fail" unknown.err
    fi
    grep -q 'unknown agent: gemini' unknown.err || fail "wrong message for unknown agent" unknown.err

    if ${run} --prompt 2>value.err; then
      fail "a flag with no value should fail" value.err
    fi
    grep -q -- '--prompt requires a value' value.err || fail "wrong message for a missing value" value.err

    if ${run} --cwd /nonexistent-dir --prompt x 2>cwd.err; then
      fail "--cwd should reject a path that is not a directory" cwd.err
    fi
    grep -q -- '--cwd is not a directory' cwd.err || fail "wrong message for a bad --cwd" cwd.err

    mkdir -p workdir
    ${run} --cwd "$PWD/workdir" --prompt x >/dev/null || fail "--cwd rejected a real directory" cwd.err

    if PATH=/nonexistent ${run} --prompt x 2>missing.err; then
      fail "a missing agent binary should fail" missing.err
    fi
    grep -q 'is not on PATH' missing.err || fail "wrong message for a missing binary" missing.err

    echo "code-assistant-profiles: resolver, validation, budget, target and agent-run checks OK"
    touch "$out"
  ''
