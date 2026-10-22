# The push guard's shim and override, run against real git.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  inherit (import ./_cases.nix {inherit harness lib pkgs;}) gitShim guardedSettings overrideReportingWrapper shellTools;
in
  pkgs.runCommand "git-push-guard-test" {nativeBuildInputs = [pkgs.git pkgs.jq];} ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }

    guard=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "${lib.concatStringsSep "|" shellTools}") | .hooks[] | select(.type == "command") | .command' ${guardedSettings})
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
    blocked "git --attr-source <tree> push" git -C work --attr-source HEAD push -q origin HEAD:main
    blocked "git --config-env <name>=<envvar> push" git --config-env core.pager=HOME -C work push -q origin HEAD:main
    blocked "git --namespace <name> --git-dir <dir> --work-tree <dir> push" git --namespace n --git-dir work/.git --work-tree work push -q origin HEAD:main
    blocked "git -c alias.p=push p" git -C work -c alias.p=push p -q origin HEAD:main
    blocked "a chain of aliases ending in push" git -C work -c alias.a=b -c alias.b='push -q' a origin HEAD:main
    blocked "a shell alias running git push" git -C work -c 'alias.sp=!git push' sp -q origin HEAD:main
    git -C work config alias.up push
    blocked "an alias from the repository's config" git -C work up -q origin HEAD:main
    git -C work config --unset alias.up
    git -C work -c alias.st=status st --porcelain >/dev/null || fail "an alias for a command other than push did not pass through the shim"
    git -C work -c alias.status=push status --porcelain >/dev/null || fail "an alias shadowing a git command was blocked, though git runs the command"

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
