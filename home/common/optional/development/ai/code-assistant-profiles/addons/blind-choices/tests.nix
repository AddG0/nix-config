# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{pkgs, ...}: let
  hook = import ./hooks.nix {inherit pkgs;};
  hide = "${hook "hide-pick"}/bin/blind-choices-hide-pick";
  reveal = "${hook "reveal-pick"}/bin/blind-choices-reveal-pick";

  question = pkgs.writeText "question.json" (builtins.toJSON {
    tool_use_id = "toolu_1";
    tool_input.questions = [
      {
        question = "Which approach?";
        header = "Approach";
        multiSelect = false;
        options = [
          {
            label = "Hook (Recommended)";
            description = "a";
          }
          {
            label = "Prompt";
            description = "b";
          }
          {
            label = "Both";
            description = "c";
          }
        ];
      }
      {
        question = "Scope?";
        header = "Scope";
        multiSelect = false;
        options = [
          {
            label = "Popups";
            description = "x";
          }
          {
            label = "Everywhere";
            description = "y";
          }
        ];
      }
    ];
  });
in
  pkgs.runCommand "blind-choices-test" {nativeBuildInputs = [pkgs.jq];} ''
    set -euo pipefail
    export XDG_RUNTIME_DIR="$PWD/run"
    fail() { echo "FAIL: $*" >&2; exit 1; }

    # hides the recommended label while keeping every option of every question
    result=$(${hide} < ${question})
    [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$result")" = ask ] || fail "decision is not ask"
    jq -e '[.hookSpecificOutput.updatedInput.questions[].options[].label] | any(test("Recommended"))' <<<"$result" >/dev/null \
      && fail "label still marked"
    [ "$(jq -c '[.hookSpecificOutput.updatedInput.questions[] | [.options[].label] | sort]' <<<"$result")" \
      = '[["Both","Hook","Prompt"],["Everywhere","Popups"]]' ] || fail "options lost or crossed between questions: $result"
    [ "$(jq -c '.hookSpecificOutput.updatedInput.questions[0].options[] | select(.label == "Hook") | .description' <<<"$result")" \
      = '"a"' ] || fail "description detached from its label"

    # reveals the sealed pick to the user once, then forgets it
    msg=$(${reveal} <<<'{"tool_use_id":"toolu_1"}')
    jq -e '.systemMessage | contains("Approach: Hook")' <<<"$msg" >/dev/null || fail "pick not revealed: $msg"
    [ -z "$(${reveal} <<<'{"tool_use_id":"toolu_1"}')" ] || fail "pick revealed twice"

    # leaves questions without a recommendation untouched
    [ -z "$(jq '.tool_use_id = "toolu_2" | .tool_input.questions[0].options[0].label = "Hook"' ${question} | ${hide})" ] \
      || fail "rewrote a question with no pick"
    [ ! -e "$XDG_RUNTIME_DIR/claude-blind-choices/toolu_2.json" ] || fail "sealed a question with no pick"

    # fails open without sealing when the tool_use_id is missing
    if jq 'del(.tool_use_id)' ${question} | ${hide} 2>/dev/null; then fail "accepted a missing tool_use_id"; fi
    [ ! -e "$XDG_RUNTIME_DIR/claude-blind-choices/null.json" ] || fail "sealed under null id"

    touch $out
  ''
