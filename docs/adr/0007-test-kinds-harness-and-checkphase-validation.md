---
status: accepted
date: 2026-10-21
---

# Tests by kind, one harness, and validation in the generating derivation

Supersedes in part [ADR 0006](0006-assistant-config-checks-evaluate-hosts.md):
host checks keep only the validators that need a whole config tree.

## Context and Problem Statement

Module tests grew one convention per directory. `checks/module-tests.nix`
named a check after its path (`module-test-modules-home-programs-codex`), any
`tests.nix` ran, and a misplaced file ran nowhere without failing. Each suite
printed its own `FAIL` lines through a hand-written `expect`, negative cases
went through `tryEval` and lost the error message, and the scaffolding
(`libWithCustom`, `hostStub`, `fakeClaude`) was imported by path from
`checks/module-test-support.nix`. The dependency rules of
`code-assistant-profiles` were checked by a Python script reading
`nix-instantiate --parse` output. ADR 0006 put every assistant validator in
one check per host, so a single bad plugin directory was found only by
evaluating a whole host, and the Prismantis plugin settings, written one level
too shallow, passed every test and validator.

## Decision Drivers

- A test file in the wrong place fails evaluation instead of never running.
- A failure names the behaviour, and an error case asserts the message.
- One way to evaluate a module under test.
- A rule about module dependencies is checked against what the module system
  saw, not against source text.
- A bad artefact fails where it is built, on any host that builds it.

## Considered Options

Test runner:

1. nix-unit, one check per unit suite, run on a generated file in the sandbox.
2. nix-unit's flake-parts check (`checks.nix-unit`, the whole flake evaluated
   in the sandbox).
3. Keep `lib.runTests` and the hand-written `expect`.

Check names:

4. `<kind>:<area>[:<sub>]`, from a fixed file layout; stray files throw.
5. Names derived from the path, as before.

Harness:

6. One `evalModules` harness in `checks/harness/`, with stubs and `lib.custom`
   injected through `_module.args`, handed to every test as an argument.
7. Each suite builds its own evaluation from shared helpers imported by path.

Dependency rules:

8. Provenance: `definitionsWithLocations` and `declarationPositions` of the
   evaluated options, plus the arguments each render function takes.
9. Keep the parser-based import scan.

Single-artefact validation:

10. In the generating derivation, behind a `checkConfig` option defaulting to
    true (Home Manager's sway and niri, nixpkgs' nginx and prometheus).
11. In the host check, as ADR 0006 has it.
12. As NixOS `system.checks` entries.

## Decision Outcome

Chosen: 1, 4, 6, 8 and 10.

- **nix-unit, option 1.** `expectedError.msg` asserts the message of a
  refusal, where `tryEval` only knew that something threw; failures print a
  structural diff. Each unit suite runs as its own check on a generated file
  that imports nixpkgs and the test file by store path, about 5 s. Option 2
  evaluates the whole flake inside the sandbox, which needs all 204 locked
  inputs passed as overrides, including the private `git+ssh` ones, and
  re-copies them per run. Option 3 keeps one printer per directory and no
  message assertions. The flake still exports the suites as `tests` (the
  `testsOutput` module), so `nix-unit --flake .#tests` runs them outside a
  check. Unit suites take `lib` and `pkgs` only; a test that needs the flake
  (`self.homeModules`, Home Manager) is a `files` test.
- **Names, option 4.** `checks/discovery.nix` reads `tests/` directories under
  `modules/`, `home/`, `lib/` and `checks/`: `unit.nix` and `structure.nix` are
  nix-unit suites, `files.nix` asserts on rendered files, `script.nix` runs a
  generated program against stubs; `lib/tests/<area>.nix` are unit suites;
  `_`-prefixed helpers and non-Nix data are allowed, any other `.nix` file and
  any `tests.nix` throw. The area is the module directory's name, nested under the
  module above it when that one has tests or the directory is a `targets/`
  entry, and qualified `home:` or `lib:` outside `modules/`. Option 5 named
  checks after layout, merged distinct paths, and could not tell a stray file
  from a test. `script` is a fourth kind beside the planned `unit`, `files`
  and `host`: a third of the suites run a real script against a stub, which
  is neither pure logic nor a rendered file.
- **Harness, option 6.** Home Manager's own tests inject stubs the same way.
  Option 7 is what drifted: three suites each carried a host stub.
- **Provenance, option 8.** The rules are about which module defines which
  option, which the module system records. It sees definitions and
  declarations only: a plain Nix file importing another by path is invisible
  to it, so the render rule becomes "a render function takes no `config`",
  which the function's arguments show. Option 9 needed Python, a parser
  round-trip and a probe tree to prove it read comments correctly.
- **Validation, option 10.** A generated plugin directory, a Prismantis
  `pluginDirs` entry and a Codex agent role are each checked by the derivation
  that produces them, so the host that builds them fails to build, and the
  option lets a host skip it (no network-free tool, cross builds). Option 11
  only fails `nix flake check`, and only for hosts of the current system.
  Option 12 is NixOS-only; these are Home Manager files. Validators that need
  the whole tree (`codex mcp list`, `--profile`, `doctor`, `opencode debug
  config`/`skill`, `claude doctor`) stay in `host:<host>`.

### Consequences

- Good: a new test file is run or rejected; nothing is skipped silently.
- Good: a broken plugin fails `home-manager switch` on every host, not just in
  checks.
- Good: `host:<host>` checks have names that do not depend on evaluating the
  host, so one failing host no longer hides every other check.
- Bad: a unit suite cannot use flake outputs; such cases moved to `files`.
- Bad: `addCoverage` fits only modules whose public surface is one attrset
  (`lib.custom.frontmatter`); suites over module options do not use it.
- Bad: path imports between plain Nix files are no longer checked; only module
  definitions and render-function arguments are.
- Neutral: `checkConfig = false` skips the per-artefact validators but not
  the host checks.

## Addendum, 2026-10-21: whole-tree validators run in the home's build

Supersedes the `host:<host>` parts above: `checks/hosts.nix` is gone.
`code-assistant-profiles` adds `run-validators.nix` over the home's own
assistant files to Home Manager's `home.checks`, behind
`programs.code-assistant-profiles.checkConfig` (default true). `home.checks`
is the Home Manager counterpart of option 12: its derivations are build
dependencies of the home that leave no trace in it. The research behind
option 12 missed it, so 12 was rejected as NixOS-only.

- Chosen over `host:<host>` checks because `checks/` then imports nothing
  from the module (a structure test enforces it), and the validators run on
  every `home-manager switch` and host rebuild of every platform, not only
  under `nix flake check` for hosts of the current system.
- A tool that writes config only at activation (Codex's `mutableSettings`)
  sets its validator's `staticConfig`; the check reads `home.file` from the
  home re-evaluated with it through `extendModules`.
- Kept: an enabled tool with no file or a null package throws, a run in which
  no validator ran fails, and the bad-config fixtures run through the
  fixture home's `home.checks`.
- Cost: the validators add to every rebuild of a home with an assistant;
  `checkConfig = false` skips them.

Discovery also throws on a symlink anywhere in a tests dir, a `tests`
symlink, a `.nix` file in a subdirectory of a tests dir (subdirectories hold
data only, `lib/tests/` included), and a tests dir that yields no suite; a
unit suite with no `test*` attribute fails evaluation, since nix-unit would
run nothing and pass.
