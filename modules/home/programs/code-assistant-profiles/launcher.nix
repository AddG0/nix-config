# `agent-run` — launch whichever coding agent is default, with an optional
# prompt and skill, without the caller naming the agent.
#
# Execs in the current terminal and never spawns one: a caller that wants a
# window wraps this (`ghostty -e agent-run …`), which keeps a Linux terminal out
# of a module darwin hosts also evaluate.
{
  lib,
  pkgs,
}: let
  # Flags as of codex-cli 0.147.0 and opencode 1.18.16; they move between
  # versions. promptFlag = null means the prompt is a positional after `--`.
  specs = {
    claude-code = {
      binary = "claude";
      autoApprove = ["--permission-mode" "bypassPermissions"];
      promptFlag = null;
    };

    codex = {
      binary = "codex";
      autoApprove = ["--dangerously-bypass-approvals-and-sandbox"];
      promptFlag = null;
    };

    opencode = {
      binary = "opencode";
      autoApprove = ["--auto"];
      promptFlag = "--prompt";
    };
  };
in {
  targetNames = lib.attrNames specs;

  mkLauncher = {
    agents,
    defaultAgent,
    profileBinDir,
    skillNames,
  }: let
    unspecified = lib.subtractLists (lib.attrNames specs) agents;

    # Throw rather than drop it: a silent omission would leave an enabled target
    # reporting itself as "not enabled".
    known =
      lib.throwIf (unspecified != [])
      "code-assistant-profiles/launcher.nix has no invocation spec for: ${lib.concatStringsSep ", " unspecified}"
      agents;

    agentCase =
      lib.concatMapStringsSep "\n" (
        name: let
          spec = specs.${name};
          promptArg =
            if spec.promptFlag == null
            then "--"
            else lib.escapeShellArg spec.promptFlag;
        in ''
          ${name})
            CMD=(${lib.escapeShellArgs ([spec.binary] ++ spec.autoApprove)} "$@")
            [[ -z $PROMPT ]] || CMD+=(${promptArg} "$PROMPT")
            ;;''
      )
      known;
  in
    pkgs.writeShellScriptBin "agent-run" ''
      set -euo pipefail

      # `claude` here is the profile wrapper, not the upstream binary. Prepending
      # the profile keeps this working from a systemd user unit's bare PATH.
      PATH=${lib.escapeShellArg profileBinDir}:"$PATH"

      AGENTS=${lib.escapeShellArg (lib.concatStringsSep " " known)}
      SKILLS=${lib.escapeShellArg (lib.concatStringsSep " " skillNames)}

      AGENT=${lib.escapeShellArg (
        if defaultAgent == null
        then ""
        else defaultAgent
      )}
      PROMPT=""
      SKILL=""
      CWD=""

      die() {
        echo "agent-run: $1" >&2
        shift
        for detail; do echo "  $detail" >&2; done
        exit 2
      }

      has() {
        case " $1 " in
          *" $2 "*) return 0 ;;
        esac
        return 1
      }

      needValue() {
        case "''${2-}" in
          "" | -*) die "$1 requires a value" ;;
        esac
      }

      usage() {
        cat <<'EOF'
      Usage: agent-run [options] [-- <agent args>...]

        --agent <name>    Agent to launch instead of the configured default.
        --prompt <text>   Initial prompt for the agent.
        --skill <name>    Ask the agent to use this skill, with a path fallback.
        --cwd <dir>       Run the agent in this directory.
        --list-agents     Print the available agents and exit.
        --list-skills     Print the available skills and exit.

      Anything after `--` is passed through to the agent.
      EOF
      }

      while (($#)); do
        case "$1" in
          --agent) needValue "$1" "''${2-}"; AGENT=$2; shift 2 ;;
          --agent=*) AGENT=''${1#--agent=}; shift ;;
          --prompt) needValue "$1" "''${2-}"; PROMPT=$2; shift 2 ;;
          --prompt=*) PROMPT=''${1#--prompt=}; shift ;;
          --skill) needValue "$1" "''${2-}"; SKILL=$2; shift 2 ;;
          --skill=*) SKILL=''${1#--skill=}; shift ;;
          --cwd) needValue "$1" "''${2-}"; CWD=$2; shift 2 ;;
          --cwd=*) CWD=''${1#--cwd=}; shift ;;
          --list-agents) printf '%s\n' $AGENTS; exit 0 ;;
          --list-skills) [[ -z $SKILLS ]] || printf '%s\n' $SKILLS; exit 0 ;;
          -h | --help) usage; exit 0 ;;
          --) shift; break ;;
          *) die "unexpected argument: $1" "run agent-run --help for usage" ;;
        esac
      done

      [[ -n $AGENT ]] || die "no agent selected and no default configured" \
        "set programs.code-assistant-profiles.defaultAgent, or pass --agent <name>" \
        "available: $AGENTS"

      has "$AGENTS" "$AGENT" || die "unknown agent: $AGENT" \
        "available: $AGENTS" \
        "an agent becomes available once its code-assistant-profiles target is enabled"

      if [[ -n $SKILL ]]; then
        has "$SKILLS" "$SKILL" || die "unknown skill: $SKILL" \
          "available: ''${SKILLS:-(the default profile defines none)}"

        NOTE="Use the $SKILL skill."

        [[ -z $PROMPT ]] || PROMPT+=$'\n\n'
        PROMPT+=$NOTE
      fi

      if [[ -n $CWD ]]; then
        [[ -d $CWD ]] || die "--cwd is not a directory: $CWD"
        cd "$CWD"
      fi

      case "$AGENT" in
      ${agentCase}
      esac

      if ! command -v "''${CMD[0]}" >/dev/null 2>&1; then
        echo "agent-run: agent '$AGENT' is selected but its binary is not on PATH: ''${CMD[0]}" >&2
        echo "  looked in ${profileBinDir} and the inherited PATH" >&2
        exit 127
      fi

      exec "''${CMD[@]}"
    '';
}
