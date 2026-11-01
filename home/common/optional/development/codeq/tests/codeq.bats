# codeq's commands against the Python and Java fixtures ./script.nix builds.

setup_file() {
  local java=$BATS_FILE_TMPDIR/java
  mkdir -p "$java/build/classes/java/main"
  cp -rL "$javaFixture/src" "$java/"
  chmod -R u+w "$java/src"
  local sources
  mapfile -t sources < <(find "$java/src" -name '*.java')
  javac -d "$java/build/classes/java/main" "${sources[@]}"
}

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  # Graphviz wants a writable font cache.
  export HOME=$BATS_TEST_TMPDIR
  py=$BATS_TEST_TMPDIR/py
  cp -r "$pythonFixture/proj" "$py"
  chmod -R u+w "$py"
  cp "$generatedFixture/proj/app/client_pb.py" "$py/app/"
  mkdir -p "$py/src/gen"
  cp "$py/app/logic.py" "$py/src/gen/copy.py"
  cd "$py" || return
}

# The cells of a package's row in coupling.txt, by their column names.
coupling_row() {
  awk -v p="$1" '$1 == p { printf "types=%s Ca=%s Ce=%s I=%s", $2, $3, $4, $5 }' out/coupling.txt
}

use_java() {
  cp -r "$BATS_FILE_TMPDIR/java" "$BATS_TEST_TMPDIR/java"
  cd "$BATS_TEST_TMPDIR/java" || return
}

@test "help lists the commands and says a Python-only project is not JVM" {
  run codeq
  assert_success
  assert_line --regexp '^  loc  '
  assert_line --regexp '^  complexity \[CCN\]  '
  assert_line --regexp '^  dup \[TOKENS\]  '
  assert_line --regexp '^  coupling \[PREFIX\]  '
  assert_line --regexp '^  any-language commands +yes$'
  assert_line --regexp '^  JVM commands +no$'
}

@test "loc counts the Python sources and keeps a copy of its report" {
  run codeq -o out loc
  assert_success
  assert_line --regexp '^ *Python +[1-9][0-9]* '
  assert_equal "$(cat out/loc.txt)" "$output"
}

@test "complexity flags the deeply branching function and not the simple ones" {
  codeq -o out complexity >/dev/null
  run cat out/complexity.txt
  assert_line --regexp 'classify@[0-9]+-[0-9]+@(\./)?app/logic\.py$'
  refute_output --partial "first@"
  refute_output --partial "second@"
}

@test "dup finds the block pasted twice in logic.py" {
  codeq -o out dup 20 >/dev/null
  run cat out/dup.txt
  assert_line --regexp '^Found a [0-9]+ line \([0-9]+ tokens\) duplication'
  local first second
  first=$(grep -n '^def first' app/logic.py | cut -d: -f1)
  second=$(grep -n '^def second' app/logic.py | cut -d: -f1)
  assert_line "Starting at line $first of app/logic.py"
  assert_line "Starting at line $second of app/logic.py"
}

@test "dup skips a file marked @generated and one under gen/" {
  codeq -o out dup 20 >/dev/null
  run cat out/dup.txt
  assert_success
  # The hand-written duplicate is still found, so the skips are not an empty report.
  assert_line --regexp '^Found a [0-9]+ line \([0-9]+ tokens\) duplication'
  refute_output --partial "client_pb.py"
  refute_output --partial "src/gen/"
}

@test "coupling refuses a non-JVM project and says why" {
  run codeq -o out coupling
  assert_failure
  assert_output "codeq: no Java/Kotlin sources here; 'coupling' is JVM-only"
}

@test "an unknown command fails and is named" {
  run codeq nonsense
  assert_failure
  assert_output --partial "codeq: unknown command: nonsense"
}

@test "coupling finds the root package and scores each package by its dependencies" {
  use_java
  codeq -o out coupling >/dev/null
  run cat out/coupling.txt
  assert_line "root package: com.example"
  # app depends on core, never the reverse.
  assert_equal "$(coupling_row core)" "types=1 Ca=1 Ce=0 I=0.00"
  assert_equal "$(coupling_row app)" "types=1 Ca=0 Ce=1 I=1.00"
}

@test "coupling draws the dependency between packages" {
  use_java
  codeq -o out coupling >/dev/null
  run cat out/coupling/packages.svg
  assert_success
  assert_output --partial "<svg"
  assert_output --partial "<title>app&#45;&gt;core</title>"
}

@test "the zsh completion parses" {
  zsh -n "$codeqShare/zsh/site-functions/_codeq"
}

@test "the nushell completion parses" {
  nu --no-config-file -c "use $codeqShare/nushell/vendor/autoload/codeq.nu *"
}
