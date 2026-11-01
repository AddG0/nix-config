{
  harness,
  pkgs,
  lib,
  ...
}: let
  # Paths come from $TEST_BASE, which only exists inside each test's tmpdir.
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

  # Answers the script's one query, whatever its text: these are registered.
  fakeSqlite3 = pkgs.writeShellScriptBin "sqlite3" ''
    set -euo pipefail
    printf '%s\n' "$TEST_BASE/known-present" "$TEST_BASE/known-missing" "$HAND_REGISTERED"
  '';

  fakeT3 = pkgs.writeShellScriptBin "t3" ''
    set -euo pipefail
    printf '%s\n' "$*" >> "$T3_LOG"
  '';
in
  harness.bats "t3code-sync-projects-test" [./sync-projects.bats] {
    nativeBuildInputs = [pkgs.jq pkgs.gnugrep pkgs.findutils];
    syncScript = ../scripts/sync-projects.sh;
    stubPath = lib.makeBinPath [fakeGwq fakeSqlite3 fakeT3];
  }
