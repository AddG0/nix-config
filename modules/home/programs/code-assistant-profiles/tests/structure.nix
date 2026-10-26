# One-way dependencies between the shared profile model, the targets and the tool modules, read off what the module system recorded.
{
  harness,
  lib,
  ...
}: let
  inherit (import ./_areas.nix {inherit lib;}) areas areasOf helpers;

  root = toString ../.;
  targetsDir = "${root}/targets";
  targetNames = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../targets));
  under = dir: file: toString file == dir || lib.hasPrefix "${dir}/" (toString file);
  ownFiles = lib.filter (under root);
  targetOf = file: lib.head (lib.splitString "/" (lib.removePrefix "${targetsDir}/" (toString file)));

  evaluated = harness.evaluate [
    harness.stubs.tools
    (harness.module ../default.nix)
    {
      programs.code-assistant-profiles = {
        enable = true;
        targets = lib.genAttrs targetNames (_: {enable = true;});
        profiles.default = {
          instructions.text = "base";
          skills.s.prompt.text = "s";
          agents.a.prompt.text = "a";
          commands.c.content.text = "c";
          mcpServers.m.command = "m";
        };
        profiles.other = {
          extends = "default";
          skills.s.prompt.text = "other s";
        };
      };
    }
  ];
  inherit (evaluated) options;

  cfg = options.programs.code-assistant-profiles;
  sharedOptions = lib.collect lib.isOption (removeAttrs cfg ["targets"]);
  # `targets.<t>.enable` is the shared model's; everything else under `targets.<t>` is that target's.
  targetOptions = lib.collect lib.isOption (cfg.targets.type.getSubOptions cfg.targets.loc);
  misplaced = option: file: let
    target = lib.elemAt option.loc 3;
  in
    if lib.elemAt option.loc 2 != "targets"
    then under targetsDir file
    else if under targetsDir file
    then !(under "${targetsDir}/${target}" file)
    else lib.last option.loc != "enable";
  misplacedIn = lib.concatMap (option: map (file: "${lib.showOption option.loc}: ${file}") (lib.filter (misplaced option) (ownFiles option.declarations)));
  misplacedDeclarations = misplacedIn (sharedOptions ++ targetOptions);

  # Each tool module's options, and the one target that writes them.
  toolWriters = {
    codex = "codex";
    opencode = "opencode";
    claude-code-profiles = "claude-code";
  };
  foreignWrites = tool: target: defs:
    map (def: "programs.${tool}: ${def.file}")
    (lib.filter (def: under root def.file && !(under "${targetsDir}/${target}" def.file)) defs);
  foreignToolWrites = lib.concatLists (lib.mapAttrsToList (tool: target: foreignWrites tool target options.programs.${tool}.definitionsWithLocations) toolWriters);

  registrationsOf = defs: lib.zipAttrs (map (def: {${targetOf def.file} = lib.attrNames def.value;}) (lib.filter (def: under targetsDir def.file) defs));
  validatorRegistrations = registrationsOf cfg.validators.definitionsWithLocations;

  takingConfig = lib.filterAttrs (_: args: lib.elem "config" args);
  argsOf = render: lib.attrNames (builtins.functionArgs render);
  renderArgs = lib.genAttrs (lib.filter (name: builtins.pathExists (../targets + "/${name}/render.nix")) targetNames) (name: argsOf (import (../targets + "/${name}/render.nix")));

  # checks/ only enumerates and runs tests; a module's validators run in the home's own build.
  checksRoot = toString (harness.root + "/checks");
  namesProfilesModule = lib.hasInfix "programs/code-assistant-profiles";
  checksNamingProfiles = map (lib.removePrefix "${checksRoot}/") (lib.filter (file: namesProfilesModule (builtins.readFile file)) (map toString (lib.filesystem.listFilesRecursive checksRoot)));

  claudeAlone = harness.eval [
    (harness.module ../../claude-code)
    {
      programs.claude-code-profiles = {
        enable = true;
        package = harness.stubs.claude;
        profiles.default.settings.model = "opus";
      };
    }
  ];

  # Scaffolding lives once in checks/harness; these needles are what a copy of it would carry.
  scaffoldingCopies = text: lib.filter (needle: lib.hasInfix needle text) ["lib.extend (final" "if (( $# )); then" "home.homeDirectory = lib.mkOption" "programs.code-assistant-profiles = lib.mkOption" "../../../../"];
  scaffoldingUsers = [
    ../../claude-code/tests/unit.nix
    ./_fixtures.nix
    ../../../../../home/common/optional/development/ai/claude-code/git-push-guard/tests/_cases.nix
  ];
in {
  "test the shared model declares no target's option, and a target only its own" = {
    expr = misplacedDeclarations;
    expected = [];
  };
  "test the declaration check reports a shared option declared in a target, and a target's option declared in another target or the shared model" = {
    expr = misplacedIn [
      {
        loc = ["programs" "code-assistant-profiles" "budgets"];
        declarations = ["${targetsDir}/codex/options.nix"];
      }
      {
        loc = ["programs" "code-assistant-profiles" "targets" "codex" "hooks"];
        declarations = ["${targetsDir}/opencode/options.nix"];
      }
      {
        loc = ["programs" "code-assistant-profiles" "targets" "codex" "hooks"];
        declarations = ["${root}/options/default.nix"];
      }
      {
        loc = ["programs" "code-assistant-profiles" "targets" "codex" "enable"];
        declarations = ["${root}/options/default.nix"];
      }
    ];
    expected = [
      "programs.code-assistant-profiles.budgets: ${targetsDir}/codex/options.nix"
      "programs.code-assistant-profiles.targets.codex.hooks: ${targetsDir}/opencode/options.nix"
      "programs.code-assistant-profiles.targets.codex.hooks: ${root}/options/default.nix"
    ];
  };
  "test only a tool's own target writes into that tool module" = {
    expr = foreignToolWrites;
    expected = [];
  };
  "test the tool-write check reports a write from the shared model or another target, and ignores files outside the module" = {
    expr = foreignWrites "codex" "codex" [
      {file = "${root}/default.nix";}
      {file = "${targetsDir}/opencode/default.nix";}
      {file = "${targetsDir}/codex/default.nix";}
      {file = "/elsewhere/home.nix";}
    ];
    expected = ["programs.codex: ${root}/default.nix" "programs.codex: ${targetsDir}/opencode/default.nix"];
  };
  "test the declaration check reads each target's own options" = {
    expr = lib.sort (a: b: a < b) (lib.unique (map (option: lib.elemAt option.loc 3) (lib.filter (option: lib.any (under targetsDir) option.declarations) targetOptions)));
    expected = lib.sort (a: b: a < b) (lib.filter (name: builtins.pathExists (../targets + "/${name}/options.nix")) targetNames);
  };
  "test the provenance check sees each target write its tool module" = {
    expr = lib.mapAttrs (tool: _: lib.any (def: under targetsDir def.file) options.programs.${tool}.definitionsWithLocations) toolWriters;
    expected = lib.mapAttrs (_: _: true) toolWriters;
  };
  "test each target registers only its own validator" = {
    expr = validatorRegistrations;
    # A validator is validator.nix, or validator/ once it has checks of its own.
    expected = lib.genAttrs (lib.filter (name: lib.any (file: builtins.pathExists (../targets + "/${name}/${file}")) ["validator.nix" "validator/default.nix"]) targetNames) (name: [[name]]);
  };
  "test the registration check attributes a validator to the target whose file registers it" = {
    expr = registrationsOf [
      {
        file = "${targetsDir}/codex/validator/default.nix";
        value = {opencode = {};};
      }
      {
        file = "${root}/default.nix";
        value = {codex = {};};
      }
    ];
    expected = {codex = [["opencode"]];};
  };
  "test a target's render function takes no config, so it reads only what it is handed" = {
    expr = takingConfig renderArgs;
    expected = {};
  };
  "test the render check reports a render function that takes config" = {
    expr = takingConfig {
      fake = argsOf ({
        config,
        lib,
      }:
        config // lib);
    };
    expected = {fake = ["config" "lib"];};
  };
  "test checks/ imports nothing from code-assistant-profiles" = {
    expr = checksNamingProfiles;
    expected = [];
  };
  "test the checks/ scan flags an import of the module" = {
    expr = namesProfilesModule "runValidators = import ../modules/home/programs/code-assistant-profiles/run-validators.nix {};";
    expected = true;
  };
  "test the checks/ scan reads every file under checks/" = {
    expr = lib.elem "tests.nix" (map (file: lib.removePrefix "${checksRoot}/" (toString file)) (lib.filesystem.listFilesRecursive checksRoot));
    expected = true;
  };
  "test the render check reads every target's render function" = {
    expr = lib.attrNames renderArgs;
    expected = targetNames;
  };
  "test the claude-code module evaluates without code-assistant-profiles" = {
    expr = lib.hasAttr ".config/claude-code/profiles/default/settings.json" claudeAlone.home.file;
    expected = true;
  };
  "test the standalone evaluation fails for a claude-code module that reads code-assistant-profiles" = {
    expr =
      (harness.eval [
        (harness.module ../../claude-code)
        ({config, ...}: {programs.claude-code-profiles.enable = config.programs.code-assistant-profiles.enable;})
      ])
      .home
      .file;
    expectedError.type = "EvalError";
    expectedError.msg = "code-assistant-profiles";
  };
  "test the suite runs every area file in tests/" = {
    expr = areas;
    expected = map (file: lib.removePrefix "_" (lib.removeSuffix ".nix" (baseNameOf file))) (lib.filter (file: dirOf file == ./. && lib.hasPrefix "_" (baseNameOf file) && lib.hasSuffix ".nix" file && !(lib.elem (baseNameOf file) helpers)) (lib.filesystem.listFilesRecursive ./.));
  };
  "test area discovery picks up a new area file and skips the suites, the helpers and directories" = {
    expr = areasOf {
      "files.nix" = "regular";
      "unit.nix" = "regular";
      "_fixtures.nix" = "regular";
      "_validators.nix" = "regular";
      "_areas.nix" = "regular";
      fixtures = "directory";
      "_budgets.nix" = "regular";
      "_new-area.nix" = "regular";
      "notes.md" = "regular";
    };
    expected = ["budgets" "new-area"];
  };
  "test module tests take their scaffolding from the shared support file instead of copying it" = {
    expr = map (file: scaffoldingCopies (builtins.readFile file)) scaffoldingUsers;
    expected = [[] [] []];
  };
  "test the scaffolding check flags a copied host stub" = {
    expr = scaffoldingCopies "home.homeDirectory = lib.mkOption {";
    expected = ["home.homeDirectory = lib.mkOption"];
  };
}
