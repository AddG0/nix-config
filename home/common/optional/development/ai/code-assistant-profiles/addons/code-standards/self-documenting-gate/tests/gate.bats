# The REAL self-documenting baseline and gate hooks over a scratch repo and one session.

setup() {
  load "$scratchRepo"
  scratch_repo
  session_starts
}

turn_ends() {
  run "$gate" < <(event Stop "$repo" "{\"stop_hook_active\": ${1:-false}}")
  assert_success
}

assert_held() {
  assert_equal "$(jq -r '.decision' <<<"$output")" block
  local text
  for text; do
    assert_output --partial "$text"
  done
}

assert_nudged() {
  assert_equal "$(jq -r '.decision // "none"' <<<"$output")" none
  assert_equal "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$output")" Stop
  local text
  for text; do
    assert_output --partial "$text"
  done
}

assert_ends() {
  assert_output ""
}

assert_notice() {
  assert_equal "$(jq -r '.decision // "none"' <<<"$output")" none
  assert_output --partial "$1"
}

# A function of $2 lines in language $1's syntax, written to $3.
long_function() {
  local body
  body=$(for i in $(seq 1 "$(($2 - 2))"); do echo "  x$i"; done)
  case "$1" in
  ts) printf 'export function quoteRates(): void {\n%s\n}\n' "$body" ;;
  kotlin) printf 'fun quoteRates() {\n%s\n}\n' "$body" ;;
  python) printf 'def quote_rates():\n%s\n  return 1\n' "$body" ;;
  go) printf 'package rates\nfunc QuoteRates() {\n%s\n}\n' "$body" ;;
  rust) printf 'fn quote_rates() {\n%s\n}\n' "$body" ;;
  java) printf 'class Rates {\nvoid quoteRates() {\n%s\n}\n}\n' "$body" ;;
  bash) printf 'quote_rates() {\n%s\n}\n' "$body" ;;
  esac >"$3"
}

@test "a turn that changed no code ends" {
  turn_ends
  assert_ends
}

@test "changed code with nothing to flag ends the turn" {
  printf 'export function quoteRates(): number {\n  return 1;\n}\n' >rates.ts
  echo 'export const kept = 2; // the carrier rounds up' >kept.ts
  turn_ends
  assert_ends
}

@test "a new comment block of three lines is held, two lines is not" {
  printf '// one\n// two\nexport const a = 1;\n' >two.ts
  printf '# one\n# two\n# three\nx = 1\n' >three.py
  turn_ends
  assert_held "Fix:" "three.py:1  3-line comment block"
  refute_output --partial "two.ts"
}

@test "a comment block that was already there is not held when the session edits nearby" {
  printf '# one\n# two\n# three\nx = 1\n' >legacy.py
  commit_all legacy
  session=s2
  session_starts
  printf '# one\n# two\n# three\nx = 2\n' >legacy.py
  turn_ends
  assert_ends
}

@test "a new file named like a grab-bag is held, an existing one the session edits is not" {
  echo 'export const old = 1;' >helpers.ts
  commit_all helpers
  session=s3
  session_starts
  echo 'export const old = 2;' >helpers.ts
  echo 'export const a = 1;' >utils.ts
  turn_ends
  assert_held "utils.ts:1  named like a grab-bag"
  refute_output --partial "helpers.ts"
}

@test "a long function is a nudge in each language, not a hold" {
  long_function ts 60 a.ts
  long_function kotlin 60 b.kt
  long_function python 60 c.py
  long_function go 60 d.go
  long_function rust 60 e.rs
  long_function java 60 F.java
  long_function bash 60 g.sh
  turn_ends
  assert_nudged "Look, and leave it" a.ts b.kt c.py d.go e.rs F.java g.sh "is 60 lines"
}

@test "a 50-line function passes, and a long function the session didn't touch is not flagged" {
  long_function kotlin 50 short.kt
  long_function kotlin 70 old.kt
  commit_all old
  session=s4
  session_starts
  long_function kotlin 50 short.kt
  printf '\nfun other() = 1\n' >>old.kt
  turn_ends
  assert_ends
}

@test "a new type whose name another file declares is a nudge naming that file" {
  mkdir -p access/domain
  echo 'data class PersonId(val value: String)' >access/domain/PersonId.kt
  commit_all person
  session=s5
  session_starts
  printf 'package access\n\ndata class PersonId(val value: Long)\n' >access/PublicPersonId.kt
  turn_ends
  assert_nudged "access/PublicPersonId.kt:3" '`PersonId` is also declared in access/domain/PersonId.kt'
}

@test "a nudge is shown once: stopping again, or a new turn with the same findings, ends quietly" {
  long_function kotlin 60 rates.kt
  turn_ends
  assert_nudged "rates.kt"
  turn_ends true
  assert_ends
  turn_ends
  assert_ends
}

@test "stopping again with a fix left undone ends the turn and names it to the user" {
  printf '# one\n# two\n# three\nx = 1\n' >three.py
  turn_ends
  assert_held "three.py"
  turn_ends true
  assert_notice "the turn ended with these unfixed"
  assert_output --partial "three.py:1"
}

@test "fixing a held finding clears it, and a new one is held afresh" {
  printf '# one\n# two\n# three\nx = 1\n' >three.py
  turn_ends
  printf '# why\nx = 1\n' >three.py
  turn_ends true
  assert_ends
  echo 'export const a = 1;' >misc.ts
  turn_ends
  assert_held "misc.ts"
}

@test "docs at the root, markdown and deleted files are not checked" {
  mkdir -p docs
  printf '# one\n# two\n# three\nx = 1\n' >docs/example.py
  printf '# notes\n# more\n# more\n' >NOTES.md
  git rm -q kept.ts
  turn_ends
  assert_ends
}

@test "an extensionless script is checked" {
  printf '#!/usr/bin/env bash\n# one\n# two\n# three\necho hi\n' >deploy
  turn_ends
  assert_held "deploy:2"
}

@test "a turn paused on a background subagent is not checked" {
  printf '# one\n# two\n# three\nx = 1\n' >three.py
  run "$gate" < <(event Stop "$repo" '{"background_tasks": [{"id": "a1", "type": "subagent"}]}')
  assert_success
  assert_ends
}

@test "a background shell, such as a dev server, does not pause the check" {
  printf '# one\n# two\n# three\nx = 1\n' >three.py
  run "$gate" < <(event Stop "$repo" '{"background_tasks": [{"id": "b1", "type": "shell", "command": "npm run dev"}]}')
  assert_success
  assert_held "three.py"
}

@test "work left uncommitted before the session started is not checked until the session changes it" {
  printf '# one\n# two\n# three\nx = 1\n' >early.py
  session=s6
  session_starts
  turn_ends
  assert_ends
  printf '# one\n# two\n# three\nx = 1\ny = 2\n# a\n# b\n# c\n' >early.py
  turn_ends
  assert_held "early.py:6"
  refute_output --partial "early.py:1"
}

@test "content pulled from the upstream branch is not checked" {
  other=$BATS_TEST_TMPDIR/other
  git clone -q "$repo" "$other"
  printf '# one\n# two\n# three\nx = 1\n' >"$other/pulled.py"
  git -C "$other" add -A
  git -C "$other" commit -qm upstream
  git remote add origin "$other"
  git fetch -q origin
  git branch -q -u origin/main
  git pull -q --ff-only
  turn_ends
  assert_ends
}

@test "a local upstream doesn't exempt the session's own work" {
  git checkout -q -b feat
  git branch -q -u main
  printf '# one\n# two\n# three\nx = 1\n' >mine.py
  commit_all mine
  git branch -f main feat
  turn_ends
  assert_held "mine.py"
}

@test "starting a session and checking a turn leave the real index alone" {
  echo 'export const kept = 2;' >kept.ts
  git add kept.ts
  before=$(sha1sum .git/index)
  session=s7
  session_starts
  echo 'export const a = 1;' >utils.ts
  turn_ends
  assert_held "utils.ts"
  assert_equal "$(sha1sum .git/index)" "$before"
}

@test "an unreadable file or an empty nested repo doesn't stop the check" {
  echo 'export const locked = 1;' >locked.ts
  chmod 000 locked.ts
  git init -q scratch
  echo 'export const a = 1;' >utils.ts
  turn_ends
  chmod 600 locked.ts
  assert_held "utils.ts"
}

@test "a snapshot git can't write fails the hook with the reason" {
  echo 'export const kept = 2;' >kept.ts
  chmod -R a-w .git/objects
  run "$gate" < <(event Stop)
  chmod -R u+w .git/objects
  assert_failure 1
  assert_output --partial "could not snapshot"
}

@test "a lost baseline restarts counting from now and says so" {
  rm -rf .git/self-documenting/baselines
  echo 'export const a = 1;' >utils.ts
  turn_ends
  assert_notice "count from now"
  turn_ends
  assert_ends
}

@test "a baseline gc pruned restarts counting from now and says so" {
  echo 'export const kept = 2;' >kept.ts
  session=s8
  session_starts
  git gc -q --prune=now
  turn_ends
  assert_notice "count from now"
}

@test "a resumed session whose baseline didn't survive says so" {
  rm -rf .git/self-documenting/baselines
  run "$baseline" < <(event SessionStart "$repo" '{"source": "resume"}')
  assert_success
  assert_output --partial "count from now"
}

@test "a repo with no commits checks a file the session adds" {
  fresh=$BATS_TEST_TMPDIR/fresh
  git init -q -b main "$fresh"
  session_starts "$fresh"
  echo 'export const a = 1;' >"$fresh/utils.ts"
  run "$gate" < <(event Stop "$fresh")
  assert_success
  assert_held "utils.ts"
}

@test "git config self-documenting.gate off ends the turn" {
  echo 'export const a = 1;' >utils.ts
  git config self-documenting.gate off
  turn_ends
  assert_ends
}

@test "outside a git repo the turn ends" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  run "$gate" < <(event Stop "$BATS_TEST_TMPDIR/plain")
  assert_success
  assert_ends
}

@test "a repo git refuses to read fails the hook with git's reason instead of passing silently" {
  printf '[broken\n' >>.git/config
  run "$gate" < <(event Stop)
  assert_failure 1
  assert_output --partial "self-documenting:"
}

@test "a path with spaces is checked" {
  mkdir -p "rate tables"
  printf '# one\n# two\n# three\nx = 1\n' >"rate tables/zone map.py"
  turn_ends
  assert_held "rate tables/zone map.py:1"
}

@test "long functions in several files are shown once, whatever order ast-grep reports them in" {
  for n in a b c d e f; do long_function kotlin 60 "$n.kt"; done
  printf '# one\n# two\n# three\nx = 1\n' >three.py
  turn_ends
  assert_held "three.py"
  for _ in 1 2 3; do
    turn_ends true
    assert_notice "unfixed"
  done
}

@test "a flagged function that grows by a line is not shown again" {
  long_function kotlin 60 rates.kt
  turn_ends
  assert_nudged "rates.kt"
  long_function kotlin 61 rates.kt
  turn_ends
  assert_ends
}

@test "work this machine pushed to the upstream is still checked" {
  printf '# one\n# two\n# three\nx = 1\n' >three.py
  commit_all work
  git remote add origin "$BATS_TEST_TMPDIR/nowhere"
  git update-ref -m "update by push" refs/remotes/origin/main HEAD
  git branch -q -u origin/main
  assert_equal "$(git rev-parse --symbolic-full-name '@{upstream}')" refs/remotes/origin/main
  turn_ends
  assert_held "three.py"
}

@test "a type name declared in hundreds of files doesn't crash the check" {
  mkdir -p components
  for i in $(seq 1 300); do echo "interface Props { a: number }" >"components/Component$i.tsx"; done
  commit_all many
  session=s9
  session_starts
  echo 'interface Props { b: number }' >components/New.tsx
  turn_ends
  assert_nudged "components/New.tsx:1"
}

@test "preprocessor lines, operator continuations and docstring bullets are not comment blocks" {
  printf '#ifdef _WIN32\n# include <windows.h>\n# define A 1\n# define B 2\n#endif\n' >compat.h
  printf 'def t(a, b, c, d):\n    return (\n        a\n        * b\n        * c\n        * d\n    )\n' >price.py
  printf 'def q():\n    """Quote.\n\n    * a\n    * b\n    * c\n    """\n' >quote.py
  turn_ends
  assert_ends
}

@test "an external diff tool doesn't hide a modified file" {
  echo 'x = 1' >a.py
  commit_all a
  session=s10
  session_starts
  printf '#!/bin/sh\necho changed\n' >"$BATS_TEST_TMPDIR/difft"
  chmod +x "$BATS_TEST_TMPDIR/difft"
  git config diff.external "$BATS_TEST_TMPDIR/difft"
  printf 'x = 1\n# one\n# two\n# three\ny = 2\n' >a.py
  turn_ends
  assert_held "a.py:2"
}

@test "a path with glob characters is diffed alone" {
  printf 'export const a = 1;\n// one\n// two\n// three\nexport const z = 1;\n' >'[id].tsx'
  echo 'export const b = 1;' >i.tsx
  commit_all glob
  session=s11
  session_starts
  printf 'export const a = 1;\n// one\n// two\n// three\nexport const z = 2;\n' >'[id].tsx'
  printf 'export const b = 1;\nexport const c = 1;\n' >i.tsx
  turn_ends
  assert_ends
}

@test "reindenting a comment block that was already there doesn't make it new" {
  printf 'def a():\n  # one\n  # two\n  # three\n  return 1\n' >legacy.py
  commit_all legacy
  session=s12
  session_starts
  printf 'def a():\n    # one\n    # two\n    # three\n    return 1\n' >legacy.py
  turn_ends
  assert_ends
}

@test "markdown, shell's type builtin, odd paths and aliases don't count as colliding declarations" {
  mkdir -p docs
  printf '```kotlin\ndata class PersonId(val value: String)\n```\n' >docs/guide.md
  printf '#!/usr/bin/env bash\ntype jq\n' >old.sh
  printf 'package carrier\ntype Quote struct{}\n' >quote.go
  commit_all decl
  session=s13
  session_starts
  mkdir -p 'café'
  printf 'class Tarif(val v: Int)\n' >'café/Tarif.kt'
  printf 'data class PersonId(val value: Long)\n' >PersonId.kt
  printf '#!/usr/bin/env bash\ntype jq\n' >new.sh
  printf 'package rates\ntype Quote = carrier.Quote\n' >rates.go
  turn_ends
  assert_ends
}

@test "editing a type that already existed doesn't report it as a new name" {
  mkdir -p a b
  echo 'data class PersonId(val value: String)' >a/PersonId.kt
  echo 'data class PersonId(val value: String)' >b/PersonId.kt
  commit_all both
  session=s14
  session_starts
  echo 'data class PersonId(val value: String, val source: String)' >b/PersonId.kt
  turn_ends
  assert_ends
}
