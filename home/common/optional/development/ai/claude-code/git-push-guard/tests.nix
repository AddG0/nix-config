# Auto-discovered by checks/module-tests.nix; also covers the addons' Claude settings hooks, merged beside the guard's.
{
  pkgs,
  lib,
  ...
}: let
  claudeModule = ../../../../../../../modules/home/programs/claude-code;
  addonDir = ../../code-assistant-profiles/addons;
  pushGuard = ./.;

  fakeClaude = pkgs.writeShellScriptBin "claude" ''
    if (( $# )); then
      printf '%s\n' "$@"
    fi
  '';

  # `nix flake check` hands perSystem a plain nixpkgs lib; the module reads lib.custom.
  libWithCustom =
    if lib ? custom
    then lib
    else lib.extend (final: _: {custom = import ../../../../../../../lib {lib = final;};});

  claudeSettingsHooks = import (claudeModule + "/settings-hooks.nix") {
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
      programs.git.package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.git;
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
          (lib.modules.importApply (claudeModule + "/default.nix") {customLib = libWithCustom.custom;})
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

  # The shape a settings hook user's module produced while settings was freeform JSON.
  legacySettingsHooksOf = module: path:
    lib.getAttrFromPath path
    (lib.evalModules {
      modules = [
        module
        {
          options.programs.claude-code-profiles = lib.mkOption {type = lib.types.anything;};
          config._module.args = {inherit pkgs;};
        }
      ];
    })
    .config
    .programs
    .claude-code-profiles;

  typedSettingsHooksOf = module: path: claudeSettingsHooks.render (lib.getAttrFromPath path (evalClaude [module]).programs.claude-code-profiles);

  settingsHookUsers = {
    git-push-guard = {
      module = pushGuard;
      path = ["baseConfig" "settings" "hooks"];
    };
    blind-choices = {
      module = addonDir + "/blind-choices/claude-code.nix";
      path = ["addons" "blind-choices" "settings" "hooks"];
    };
    design-notes = {
      module = addonDir + "/design-notes/claude-code.nix";
      path = ["addons" "design-notes" "settings" "hooks"];
    };
    code-standards = {
      module = addonDir + "/code-standards/claude-code.nix";
      path = ["addons" "code-standards" "settings" "hooks"];
    };
    spec-driven-dev = {
      module = addonDir + "/spec-driven-dev/claude-code.nix";
      path = ["addons" "spec-driven-dev" "settings" "hooks"];
    };
  };

  includeAddon = name: {config, ...}: {
    programs.claude-code-profiles.profiles.default.include = [config.programs.claude-code-profiles.addons.${name}];
  };

  guarded = evalClaude [pushGuard (addonDir + "/blind-choices/claude-code.nix") (includeAddon "blind-choices") {programs.claude-code-profiles.profiles.default = {};}];
  guardedSettings = guarded.home.file.".config/claude-code/profiles/default/settings.json".source;
  renderedOf = config:
    (import (claudeModule + "/profile-files.nix") {
      inherit claudeSettingsHooks lib pkgs;
      resolvedProfiles = {};
    }).renderSettings
    config.programs.claude-code-profiles.resolved.default.settings;

  pushGuardCommand = lib.concatMap (group: map (handler: handler.command) group.hooks) (lib.filter (group: group.matcher or null == "Bash") ((renderedOf guarded).hooks.PreToolUse or []));

  gitShim = lib.getExe (lib.findSingle (package: lib.getName package == "git") (throw "git-push-guard tests: no git shim in extraPath") (throw "git-push-guard tests: two git shims in extraPath") guarded.programs.claude-code-profiles.extraPath);

  # Reports the override as Claude would see it, so the wrapper's environment is what's tested.
  overrideReportingWrapper =
    (evalClaude [
      pushGuard
      {
        programs.claude-code-profiles.package = lib.mkForce (pkgs.writeShellScriptBin "claude" ''echo "''${ALLOW_GIT_PUSH-unset}"'');
        programs.claude-code-profiles.profiles.default = {};
      }
    ]).programs.claude-code-profiles.wrapperPackage;

  failedAssertions = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);

  # Pure, so a failure throws while the check evaluates.
  settingsHookFailures = lib.runTests {
    testSettingsHookUsersRenderTheShapeTheyWroteAsFreeformSettings = {
      expr = lib.mapAttrs (_: user: typedSettingsHooksOf user.module user.path) settingsHookUsers;
      expected = lib.mapAttrs (_: user: legacySettingsHooksOf user.module user.path) settingsHookUsers;
    };
    testPushGuardLandsInRenderedSettingsAsABashPreToolUseHook = {
      expr = map (lib.hasSuffix "/bin/claude-ask-on-push-override") pushGuardCommand;
      expected = [true];
    };
    testPushGuardAndAnAddonPreToolUseHookBothSurviveMerging = {
      expr = map (group: group.matcher) (renderedOf guarded).hooks.PreToolUse;
      expected = ["Bash" "AskUserQuestion"];
    };
    testMigratedSettingsHookUsersRaiseNoAssertions = {
      expr = failedAssertions (evalClaude (lib.mapAttrsToList (_: user: user.module) settingsHookUsers
        ++ map includeAddon ["blind-choices" "design-notes" "code-standards" "spec-driven-dev"]
        ++ [{programs.claude-code-profiles.profiles.default = {};}]));
      expected = [];
    };
  };
in
  lib.throwIf (settingsHookFailures != [])
  "git-push-guard settings hook tests failed:\n${lib.generators.toPretty {} settingsHookFailures}"
  pkgs.runCommand "git-push-guard-test" {nativeBuildInputs = [pkgs.git pkgs.jq];} ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }

    guard=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.type == "command") | .command' ${guardedSettings})
    case "$guard" in
      */bin/claude-ask-on-push-override) ;;
      *) fail "push guard missing from rendered settings.json: $guard" ;;
    esac
    [ -x "$guard" ] || fail "push guard command is not executable: $guard"

    decision() { jq -r '.hookSpecificOutput | "\(.permissionDecision): \(.permissionDecisionReason)"'; }

    reply=$(echo 'not json' | "$guard" 2>/dev/null) || fail "unreadable hook input made the hook fail, which Claude treats as non-blocking"
    [ "$(decision <<<"$reply")" = "ask: git-push-guard could not read the hook input" ] || fail "unreadable hook input did not ask: $reply"

    reply=$(jq -n '{tool_input: {command: "ALLOW_GIT_PUSH=1 git push"}}' | "$guard")
    [ "$(decision <<<"$reply")" = "ask: ALLOW_GIT_PUSH (git push)" ] || fail "setting ALLOW_GIT_PUSH did not ask: $reply"

    reply=$(jq -n '{tool_input: {command: "git status"}}' | "$guard")
    [ -z "$reply" ] || fail "a command without ALLOW_GIT_PUSH was asked about: $reply"

    root=$PWD
    export HOME="$root/home"
    mkdir -p "$HOME" shim

    mkdir -p "$HOME/.config/claude-code/profiles/default"
    seen=$(ALLOW_GIT_PUSH=1 ${overrideReportingWrapper}/bin/claude) || fail "the claude wrapper did not start"
    [ "$seen" = unset ] || fail "an ALLOW_GIT_PUSH inherited from the launching shell reached claude: $seen"
    ln -s ${gitShim} shim/git
    export PATH="$root/shim:$PATH"
    git config --global user.name t
    git config --global user.email t@example.invalid
    git config --global init.defaultBranch main

    git init -q --bare remote.git
    git init -q work
    echo one >work/file
    git -C work add file
    git -C work commit -qm one
    git -C work remote add origin "$root/remote.git"

    remoteHasMain() { git -C "$root/remote.git" rev-parse -q --verify refs/heads/main >/dev/null; }
    git -C "$root/remote.git" rev-parse --git-dir >/dev/null || fail "the bare remote is unreadable, so a blocked push would pass unchecked"

    blocked() {
      local label=$1
      shift
      if "$@" 2>"$root/blocked.err"; then
        fail "$label: push was not blocked"
      fi
      grep -q 'git push blocked: rerun as ALLOW_GIT_PUSH=1 git ' "$root/blocked.err" || fail "$label: no rerun hint: $(cat "$root/blocked.err")"
      ! remoteHasMain || fail "$label: the push reached the remote"
    }

    (cd work && blocked "ALLOW_GIT_PUSH unset" env -u ALLOW_GIT_PUSH git push -q origin HEAD:main)
    (cd work && blocked "ALLOW_GIT_PUSH empty" env ALLOW_GIT_PUSH= git push -q origin HEAD:main)
    (cd work && blocked "ALLOW_GIT_PUSH=0" env ALLOW_GIT_PUSH=0 git push -q origin HEAD:main)
    (cd work && blocked "ALLOW_GIT_PUSH=false" env ALLOW_GIT_PUSH=false git push -q origin HEAD:main)
    blocked "git -C dir push" git -C work push -q origin HEAD:main
    (cd work && blocked "git -c k=v push" git -c push.default=current push -q origin HEAD:main)

    echo two >work/file
    git -C work stash push -q || fail "git stash push did not pass through the shim"
    [ "$(git -C work stash list | wc -l)" = 1 ] || fail "git stash push did not reach real git"

    git -C work status --porcelain >status.out || fail "git status did not pass through the shim"
    [ ! -s status.out ] || fail "the stash left the worktree dirty: $(cat status.out)"

    ALLOW_GIT_PUSH=1 git -C work push -q origin HEAD:main || fail "ALLOW_GIT_PUSH=1 push did not reach real git"
    remoteHasMain || fail "ALLOW_GIT_PUSH=1 push did not land on the remote"

    # A claude started inside an older session's shell also has that session's shim, which looked git up on PATH.
    mkdir older-shim
    cat >older-shim/git <<'SH'
    #!${pkgs.runtimeShell}
    self=''${0%/*}
    exec "$(PATH=$(printf '%s' "$PATH" | tr : '\n' | grep -vxF "$self" | paste -sd:) command -v git)" "$@"
    SH
    chmod +x older-shim/git
    attempt=0
    for order in "$root/shim:$root/older-shim" "$root/older-shim:$root/shim"; do
      branch=two-shims-$((++attempt))
      ALLOW_GIT_PUSH=1 PATH="$order:$PATH" timeout 10 git -C work push -q origin "HEAD:$branch" \
        || fail "an approved push with PATH $order did not reach real git (rc $?, 124 = looped until timeout)"
      git -C "$root/remote.git" rev-parse -q --verify "refs/heads/$branch" >/dev/null || fail "an approved push with PATH $order did not land on the remote"
    done

    touch "$out"
  ''
