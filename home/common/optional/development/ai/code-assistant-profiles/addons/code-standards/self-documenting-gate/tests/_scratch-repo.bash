# Shared by ./gate.bats: a scratch repo and the hook events one session sends.

scratch_repo() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export HOME=$BATS_TEST_TMPDIR/home XDG_RUNTIME_DIR=$BATS_TEST_TMPDIR/run GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  mkdir -p "$HOME"
  repo=$BATS_TEST_TMPDIR/repo
  git init -q -b main "$repo"
  cd "$repo" || return
  echo 'export const kept = 1;' >kept.ts
  commit_all init
}

commit_all() {
  git add -A
  git commit -qm "$1"
}

# A hook event for session ${session:-s1}; extra fields as a JSON object in $3.
event() {
  local extra=${3:-}
  jq -nc --arg s "${session:-s1}" --arg e "$1" --arg cwd "${2:-$repo}" --argjson extra "${extra:-null}" \
    '{session_id: $s, hook_event_name: $e, cwd: $cwd} + ($extra // {})'
}

# shellcheck disable=SC2154 # tests/script.nix sets $baseline
session_starts() {
  event SessionStart "${1:-$repo}" | "$baseline"
}
