# agent-run, the launcher, and the reserved-file guard a skill resourcesRoot passes through.
{
  lib,
  pkgs,
  self,
  ...
}: let
  launcherModule = import ../launcher.nix {inherit lib pkgs;};
  guard = (import ../skill-resources.nix {inherit lib;}).rejectReserved "codex" "demo";

  # The packages the home config installs for each target, from the pins and overlays the hosts use.
  hostPkgs = import self.inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    overlays = [self.overlays.default];
    config.allowUnfree = true;
  };
  installed = {
    claude-code = hostPkgs.unstable.claude-code;
    inherit (hostPkgs) codex opencode;
  };

  # Every word the launcher passes as a flag or flag value must still appear in the tool's --help.
  flagWords = spec: lib.filter (word: word != null) (spec.autoApprove ++ [spec.promptFlag]);
  helpChecks = lib.concatStrings (lib.mapAttrsToList (target: spec: ''
      HOME=$TMPDIR/help-home-${target} ${lib.getExe' installed.${target} spec.binary} --help >help-${target}.txt 2>&1 && status=0 || status=$?
      for word in ${lib.escapeShellArgs (flagWords spec)}; do
        grep -qwF -- "$word" help-${target}.txt || fail "agent-run passes $word to ${spec.binary}, but ${lib.getName installed.${target}} ${lib.getVersion installed.${target}} --help (exit $status) no longer lists it" help-${target}.txt
      done
    '')
    launcherModule.specs);

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
in
  pkgs.runCommand "code-assistant-profiles-script" {} ''
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

    ${helpChecks}

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
    touch "$out"
  ''
