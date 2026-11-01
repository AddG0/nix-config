---
status: accepted
date: 2026-10-31
---

# Script tests are bats files run by `harness.bats`

Supersedes in part [ADR 0007](0007-test-kinds-harness-and-checkphase-validation.md):
the `script` kind keeps its discovery and naming, but no longer writes its own
assertions.

## Context and Problem Statement

ADR 0007 made `script.nix` a test kind: a generated program run against stubs
in a `runCommand`. Each of the 25 suites then grew its own `fail()`, `expect`
or `absent()`, announced cases with `echo "--- …"`, and stopped at the first
`exit 1`. A failure printed a hand-written message, rarely the value it got,
and hid every case after it. Cases ran in sequence on shared files, so a later
case could pass only because an earlier one had set things up.

## Decision Drivers

- A failure names the behaviour and shows expected against actual.
- Every case runs and reports, not just the ones before the first failure.
- A case sets up its own state.
- The test shell is a file shellcheck can lint, not a Nix string.
- Discovery and check names from ADR 0007 stay as they are.

## Considered Options

Assertions:

1. bats 1.14 with bats-support, bats-assert and bats-file, all in nixpkgs.
2. Keep each suite's own helpers.
3. One shared shell helper library in `checks/harness/`.

Rollout:

4. Convert every suite that asserts in bash; new script tests are bats from
   now on.
5. bats only for new or large suites, the rest left as they are.
6. Convert all 25, including those that run another language's tests.

Where the test shell lives:

7. `.bats` files beside `script.nix`, given Nix values as environment
   variables.
8. The bats text generated in Nix, with store paths interpolated.

## Decision Outcome

Chosen: 1, 4 and 7.

- **bats, option 1.** `@test` names are the behaviour, `assert_equal` and
  `assert_line` print both sides, `setup`/`teardown` give each case its own
  `$BATS_TEST_TMPDIR`, and TAP output names the failing file and line.
  Option 2 is what drifted. Option 3 would rebuild bats-assert without the
  per-test isolation or the runner.
- **Bash suites, option 4.** Option 5 leaves two styles side by side
  indefinitely, and a reader of one suite learns nothing about the next.
  Option 6 wraps a Node or Luau runner in a single `@test` and gains nothing:
  `t3code-theme` and `ai-usage` stay thin runners, `omniwm/fullscreen-hide`
  stays a jq table that already reports every case, and `desktop-sessions`
  keeps its `harness.values` and file checks in Nix, only its shell tail
  moving to bats.
- **Files, option 7.** shellcheck lints them with `-s bats`, and no `''${`
  escaping. Option 8 keeps store paths inline, but the shell becomes a Nix
  string that neither shellcheck nor an editor understands.

`harness.bats name files attrs` runs the files with the three libraries on
`BATS_LIB_PATH`; `attrs` become the tests' environment, and a derivation in
them is built first. `script.nix` stays the entry point: it builds the stubs
and fixtures and returns `harness.bats`. A suite that runs once per variant
passes `BATS_TEST_NAME_PREFIX` so each run's tests say which variant failed.

Rules every suite follows:

- A background process closes fd 3 (`cmd 3>&- &`): bats reports on fd 3 and
  waits for every holder to close it.
- A service shared by a file's tests (a server, an agent) starts in
  `setup_file` and stops in `teardown_file`; a case that changes shared state
  is undone in `setup`, not by the case itself.
- Failure context, such as a server log, is printed from `teardown` when
  `BATS_TEST_COMPLETED` is unset.
- A program run under `env -i` is named by `$(command -v …)`, since PATH is
  gone; a stub dir is prepended to PATH, never replaces it.
- A negative check is `run cmd` then `assert_failure` or `refute_*`: bash's
  errexit ignores `! cmd` and the left side of `cmd && fail`, so both pass
  silently.
- No function is named `setup`, `run`, `status`, `output` or `load` other
  than as bats defines them.
- A tmux target is exact: `=name` for a session, `name:` for a new window in
  it.

### Consequences

- Good: one failing case no longer hides the rest; the ssh pilot reported four
  independent failures in one build.
- Good: a case that only passed because of an earlier one now fails.
- Bad: suites written as one sequence (the live-tmux tests, the jetbrains
  merge) repeat their setup per case, and a per-case tmux server
  costs build time.
- Bad: bats and its libraries are a build input of every script check.
- Bad: the ssh suite's sshd wire tests and key-order checks are gone; they
  asserted the primary user's own key and forge choices, which
  `docs/conventions.md` `## Tests` rules out, and nothing replaces them.
- Neutral: `home/common/core/ssh/tests` is the reference suite; a file shared
  by one suite's `.bats` files is loaded through a store path passed in its
  attrs, since each file is copied to the store alone.
