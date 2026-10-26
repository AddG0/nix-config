# Running the validators through a home's build: a clean home passes and runs every validator each target registers.
{
  harness,
  lib,
  pkgs,
  self,
  ...
}: let
  inherit (import ./_validators.nix {inherit lib pkgs self;}) evalHome validatorRun;
  clean = validatorRun "clean" {};

  # writableConfig merges config.toml and each profile's file at activation; the check must still run over all of them.
  mutableClean = validatorRun "codex-mutable-clean" {programs.codex.writableConfig = true;};

  # A disabled file reaches the fake $HOME only when its validator lists it as merged; the build fails otherwise.
  mergedProbe = let
    file = enable: target: {
      inherit enable target;
      source = pkgs.writeText "probe" "x";
    };
  in
    import ../run-validators.nix {inherit pkgs lib;} {
      name = "fixture-merged";
      homes.t = {
        programs.code-assistant-profiles.validators.probe = {
          option = "programs.probe";
          enable = true;
          package = pkgs.hello;
          configDirs = ["probe"];
          extraDirs = [];
          mergedFiles = ["probe/merged"];
          setup = "";
          script = _: ''
            validate probe probe/merged test -f "$HOME/probe/merged"
            validate probe probe/disabled test ! -e "$HOME/probe/disabled"
          '';
        };
        home = {
          homeDirectory = "/home/t";
          file = {
            linked = file true "probe/linked";
            merged = file false "probe/merged";
            disabled = file false "probe/disabled";
          };
        };
        xdg.configHome = "/home/t/.config";
      };
    };

  # writableConfig writes config.toml only at activation; the check must still read it.
  mutable = pkgs.testers.testBuildFailure (validatorRun "codex-mutable" {
    programs.codex.writableConfig = true;
    programs.codex.settings.tui = "none";
  });

  assistantChecks = case: module: map (check: check.name) (lib.filter (check: lib.hasPrefix "assistant-config-check-" check.name) (evalHome case module).home.checks);

  # A validator that runs nothing, over a home holding one file of its tool.
  silent = pkgs.testers.testBuildFailure (import ../run-validators.nix {inherit pkgs lib;} {
    name = "fixture-silent";
    homes.t = {
      programs.code-assistant-profiles.validators.silent = {
        option = "programs.silent";
        enable = true;
        package = pkgs.hello;
        configDirs = ["silent"];
        extraDirs = [];
        mergedFiles = [];
        setup = "";
        script = _: "";
      };
      home = {
        homeDirectory = "/home/t";
        file.x = {
          enable = true;
          target = "silent/x";
          source = pkgs.writeText "x" "x";
        };
      };
      xdg.configHome = "/home/t/.config";
    };
  });
in
  pkgs.runCommand "code-assistant-profiles-files" {} ''
    ${harness.values {
      "test a home with an assistant tool adds its validator run to home.checks" = {
        expr = assistantChecks "wired" {};
        expected = ["assistant-config-check-fixture-wired"];
      };
      "test checkConfig off leaves the validators out of the home's build" = {
        expr = assistantChecks "off" {programs.code-assistant-profiles.checkConfig = false;};
        expected = [];
      };
      "test writableConfig lists config.toml and each profile's file as merged for the codex check" = {
        expr = (evalHome "merged-list" {programs.codex.writableConfig = true;}).programs.code-assistant-profiles.validators.codex.mergedFiles;
        expected = [".config/codex/config.toml" ".config/codex/alt.config.toml"];
      };
      "test a home with no assistant tool adds no validator run" = {
        expr = assistantChecks "none" {
          programs.code-assistant-profiles.targets = lib.genAttrs ["claude-code" "codex" "opencode"] (_: {enable = lib.mkForce false;});
        };
        expected = [];
      };
    }}
    for want in ${lib.escapeShellArgs [
      "claude-code: .config/claude-code/profiles/default: claude plugin validate"
      "claude-code: .config/claude-code/profiles/default/settings.json: claude doctor"
      "codex: .config/codex/config.toml: codex mcp list"
      "codex: .config/codex/alt.config.toml: codex --profile alt"
      "codex: .config/codex: codex doctor"
      "opencode: .config/opencode: opencode-config-check"
      "opencode: .config/opencode/skills: opencode-skill-check"
    ]}; do
      if ! grep -qF -- "fixture-clean: $want" ${clean}; then
        echo "FAIL: the clean check never ran: $want" >&2
        cat ${clean} >&2
        exit 1
      fi
    done
    for want in ${lib.escapeShellArgs [
      "codex: .config/codex/config.toml: codex mcp list"
      "codex: .config/codex/alt.config.toml: codex --profile alt"
    ]}; do
      if ! grep -qF -- "fixture-codex-mutable-clean: $want" ${mutableClean}; then
        echo "FAIL: under writableConfig the check never ran: $want" >&2
        cat ${mutableClean} >&2
        exit 1
      fi
    done
    if ! grep -qF "fixture-silent: no validator ran over the generated assistant config" ${silent}/testBuildFailure.log; then
      echo "FAIL: a validator run that ran nothing passed:" >&2
      cat ${silent}/testBuildFailure.log >&2
      exit 1
    fi
    # A bad config.toml reaches every codex run, so this asserts the first rather than a count.
    if ! grep -qF 'fixture-codex-mutable: codex: .config/codex/config.toml: `codex mcp list` rejected it' ${mutable}/testBuildFailure.log; then
      echo "FAIL: under writableConfig the check never saw config.toml:" >&2
      cat ${mutable}/testBuildFailure.log >&2
      exit 1
    fi
    grep -qF 'fixture-merged: probe: probe/merged' ${mergedProbe} ||
      { echo "FAIL: the merged-file probe never ran" >&2; exit 1; }
    touch "$out"
  ''
