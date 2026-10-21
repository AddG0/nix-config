# Helpers and fixtures every area file shares; each area file takes this set as its argument.
{
  pkgs,
  lib,
}: let
  skillResources = import ../skill-resources.nix {inherit lib;};
  validation = import ../validation.nix {inherit lib;};
  budgets = import ../budgets.nix {inherit lib;};
  profileSchema = import ../options/profile.nix {inherit lib;};

  # A profile as `resolved` hands it over: typed once, every default filled in.
  typed = raw:
    (lib.evalModules {
      modules = [
        {
          options.p = lib.mkOption {type = profileSchema.resolvedProfileType;};
          config.p = {name = "p";} // removeAttrs raw ["extends" "include"];
        }
      ];
    })
    .config
    .p;

  # `nix flake check` hands perSystem a plain nixpkgs lib; the module tree reads lib.custom.
  libWithCustom =
    if lib ? custom
    then lib
    else lib.extend (final: _: {custom = import ../../../../../lib {lib = final;};});

  inherit (libWithCustom.custom) frontmatter;

  # resolveProfile reads sibling profiles off cfg, so each case supplies its own.
  resolverFor = profiles:
    import ../resolve-profile.nix {
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

  tryMessage = value: let
    attempt = builtins.tryEval (builtins.deepSeq value "no throw");
  in
    if attempt.success
    then attempt.value
    else "threw";

  messagesOf = sharedConfig: map (a: a.message) (lib.filter (a: !a.assertion) (validation.validateSharedConfig "profile 'p'" (typed sharedConfig)));

  # An absence check alone passes on an empty render, so each also names text that must be there.
  expectText = label: text: {
    contains,
    lacks,
  }:
    expect label (lib.genAttrs (contains ++ lacks) (needle: lib.hasInfix needle text)) (lib.genAttrs contains (_: true) // lib.genAttrs lacks (_: false));

  expect = label: actual: expected:
    lib.optionalString (actual != expected) ''
      echo "FAIL ${label}: expected ${lib.generators.toPretty {} expected}, got ${lib.generators.toPretty {} actual}" >&2
      exit 1
    '';

  baseResolver = resolverFor {};
  normalize = baseResolver.normalizeSharedConfig;

  withInstructions = value: {instructions = value;};

  fixtureFile = ./fixtures/clean/reference.md;
  fixtureBody = builtins.readFile fixtureFile;

  sourceSpec = {
    text = null;
    source = fixtureFile;
  };

  skillEntry = attrs:
    {
      name = "s";
      description = null;
      whenToUse = null;
      argumentHint = null;
      context = null;
      reasoningEffort = null;
      agent = null;
      version = null;
      license = null;
      compatibility = null;
      metadata = {};
      model = null;
      allowedTools = [];
      paths = [];
      invocation = {
        user = true;
        model = true;
      };
      prompt = emptySpec;
    }
    // attrs;

  passthroughAgent = "---\ndescription: d\nmemory: project\nbackground: true\nmaxTurns: 5\nquoted: 'true'\ncount: 3\ntags: [a, 'b']\n---\n\nBody.";
  claudeAgentWith = attrs:
    {
      description = "A demo agent";
      prompt = spec "agent body";
      tools = ["Read"];
      disallowedTools = [];
      skills = [];
      model = null;
      color = null;
      category = "review";
      reasoningEffort = "minimal";
      maxTurns = null;
    }
    // attrs;

  mcpEntry = attrs:
    {
      type = "local";
      command = null;
      args = [];
      env = {};
      url = null;
      headers = {};
      enabled = true;
      startupTimeout = null;
      toolTimeout = null;
      cwd = null;
      headersHelper = null;
      oauth = {
        clientId = null;
        callbackPort = null;
        scopes = [];
      };
      extra = {};
    }
    // attrs;

  # Only the host options the target modules read.
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
      # Typed `enable`, so the target's mkDefault resolves and gates home.file.
      programs.codex = lib.mkOption {
        type = lib.types.submodule {
          freeformType = lib.types.attrsOf lib.types.anything;
          options.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
        default = {};
      };
      programs.opencode = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
      programs.claude-code-profiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
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

  evalTargets = profileConfig: evalProfiles {default = profileConfig;};

  evalProfiles = profiles: evalCodingConfig {programs.code-assistant-profiles = {inherit profiles;};};

  evalCodingConfig = codingModule:
    (lib.evalModules {
      # specialArg: _module.args.lib lands too late for the imported modules' own `lib`.
      specialArgs.lib = libWithCustom;
      modules = [
        hostStub
        (lib.modules.importApply ../default.nix {customLib = libWithCustom.custom;})
        {
          _module.args = {inherit pkgs;};
          programs.code-assistant-profiles = {
            enable = true;
            targets.codex.enable = true;
            targets.opencode.enable = true;
          };
        }
        codingModule
      ];
    })
    .config;

  agentWithModel = model: {
    prompt = spec "a";
    inherit model;
  };
  invocationConfig = {
    skills.manual = {
      prompt = spec "manual body";
      invocation.model = false;
    };
    skills.background = {
      prompt = spec "background body";
      invocation.user = false;
    };
    skills.versioned = {
      prompt = spec "versioned body";
      version = "1.2";
      model = "opus";
      context = "fork";
      argumentHint = "<file>";
      allowedTools = ["Read"];
    };
    skills.shared = {prompt = spec "shared body";};
    commands.shared = {content = spec "shared command";};
    commands.commit = {content = spec "commit command";};
    agents.reviewer = {prompt = spec "reviewer";};
  };
  invocationProfile = evalTargets invocationConfig;
  optionalFieldsConfig = {
    mcpServers = {
      local = {
        command = "srv";
        cwd = "/srv";
        enabled = false;
        startupTimeout = 20000;
        toolTimeout = 1500;
        extra.codex.required = true;
        extra.opencode.environment.EXTRA = "1";
      };
      remote = {
        type = "remote";
        url = "https://mcp.example";
        headersHelper = "print-headers";
        oauth = {
          clientId = "cid";
          callbackPort = 8080;
          scopes = ["read" "write"];
        };
        extra.codex.oauth.callback_url = "http://localhost:8080/cb";
      };
    };
    lspServers = {
      l = {
        command = "l";
        extensionToLanguage.".l" = "l";
        initializationOptions.formatting = true;
        extra.opencode.env.LSP = "1";
      };
      typescript.enabled = false;
      muted = {
        command = "m";
        extensionToLanguage.".m" = "m";
        enabled = false;
      };
    };
    agents.painter = {
      prompt = spec "paint";
      color = "red";
      extra.opencode = {
        mode = "primary";
        temperature = 0.2;
      };
      extra.codex.sandbox_mode = "read-only";
    };
    commands.ship = {
      content = spec "ship body";
      model = "opus";
      agent = "build";
      subtask = true;
      extra.opencode.variant = "high";
    };
    commands.qualified = {
      content = spec "qualified body";
      model = "ai-proxy/gpt-6-luna";
    };
    skills.licensed = {
      prompt = spec "licensed body";
      license = "MIT";
      metadata."short-description" = "Short";
      extra.codex.interface.display_name = "Licensed";
      extra.opencode.compatibility = "opencode >= 1.19";
    };
    skills.manualExtra = {
      prompt = spec "manual body";
      invocation.model = false;
      extra.codex.policy.products = ["codex"];
    };
  };
  codexHooked = evalTargets {};
  codexHookTargets = hooks: plugins:
    (lib.evalModules {
      specialArgs.lib = libWithCustom;
      modules = [
        hostStub
        (lib.modules.importApply ../default.nix {customLib = libWithCustom.custom;})
        {
          _module.args = {inherit pkgs;};
          programs.code-assistant-profiles = {
            enable = true;
            targets.codex = {
              enable = true;
              inherit hooks;
            };
            targets.opencode = {
              enable = true;
              inherit plugins;
            };
            profiles.default = {};
          };
        }
      ];
    })
    .config;
  failedOf = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
  manyLines = lib.concatStringsSep "\n" (builtins.genList toString 201);
in {
  inherit pkgs lib expectText skillResources validation budgets profileSchema typed libWithCustom frontmatter resolverFor emptySpec spec profile rule scopedRule tryMessage messagesOf expect baseResolver normalize withInstructions fixtureFile fixtureBody sourceSpec skillEntry passthroughAgent claudeAgentWith mcpEntry hostStub evalTargets evalProfiles evalCodingConfig agentWithModel invocationConfig invocationProfile optionalFieldsConfig codexHooked codexHookTargets failedOf manyLines;
}
