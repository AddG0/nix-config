# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  # Paths come from $TEST_BASE (set by the test below) rather than being baked
  # in, since these stubs are built once but need to check real directories
  # that only exist inside the runCommand sandbox.
  fakeGwq = pkgs.writeShellScriptBin "gwq" ''
    set -euo pipefail
    if [ "$*" = "list -g --json" ]; then
      printf '%s' "[
        {\"path\":\"$TEST_BASE/known-present\",\"is_main\":true},
        {\"path\":\"$TEST_BASE/known-missing\",\"is_main\":true},
        {\"path\":\"$TEST_BASE/new-repo\",\"is_main\":true},
        {\"path\":\"$TEST_BASE/worktree\",\"is_main\":false}
      ]"
      exit 0
    fi
    echo "unexpected gwq invocation: $*" >&2
    exit 1
  '';

  # Reports known-present, known-missing, and $HOME/nix-config as already
  # registered, regardless of the query text — the script only ever asks this
  # one question.
  fakeSqlite3 = pkgs.writeShellScriptBin "sqlite3" ''
    set -euo pipefail
    printf '%s\n' "$TEST_BASE/known-present" "$TEST_BASE/known-missing" "$HOME/nix-config"
  '';

  fakeT3 = pkgs.writeShellScriptBin "t3" ''
    set -euo pipefail
    printf '%s\n' "$*" >> "$T3_LOG"
  '';

  stubPath = lib.makeBinPath [fakeGwq fakeSqlite3 fakeT3 pkgs.jq pkgs.gnugrep pkgs.coreutils pkgs.findutils pkgs.bash];
in
  pkgs.runCommand "t3code-sync-projects-test" {} ''
    export PATH="${stubPath}"
    export T3_LOG="$PWD/t3.log"
    export T3CODE_STATE_DB="$PWD/state.sqlite"
    export TEST_BASE="$PWD/repos"
    export HOME="$PWD/home"
    touch "$T3_LOG" "$T3CODE_STATE_DB"

    # known-missing and new-repo are deliberately never created: the first
    # exercises pruning, the second only needs to be absent from $known.
    # $HOME/nix-config is also never created, to prove the hardcoded
    # exclusion — not mere luck — is what keeps it unpruned.
    mkdir -p "$TEST_BASE/known-present" "$HOME"

    bash ${./scripts/sync-projects.sh}

    if grep -qx "project add $TEST_BASE/known-present" "$T3_LOG"; then
      echo "FAIL: already-known project was re-added" >&2
      exit 1
    fi

    if grep -qx "project add $TEST_BASE/worktree" "$T3_LOG"; then
      echo "FAIL: a gwq worktree was registered as a project" >&2
      exit 1
    fi

    grep -qx "project add $TEST_BASE/new-repo" "$T3_LOG" || {
      echo "FAIL: the new project was not added" >&2
      exit 1
    }

    if grep -qx "project remove $TEST_BASE/known-present" "$T3_LOG"; then
      echo "FAIL: a still-present project was pruned" >&2
      exit 1
    fi

    grep -qx "project remove $TEST_BASE/known-missing" "$T3_LOG" || {
      echo "FAIL: a project whose directory is gone was not pruned" >&2
      exit 1
    }

    if grep -qx "project remove $HOME/nix-config" "$T3_LOG"; then
      echo "FAIL: \$HOME/nix-config was pruned despite the special case" >&2
      exit 1
    fi

    echo "t3code-sync-projects: add, dedup, worktree filtering, and prune OK"
    touch $out
  ''
