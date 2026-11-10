# The mechanical half of the self-documenting rule, over lines this session added; prepended to gate.sh by hooks.nix.
# Each finding is "<fix|look>\t<path>\t<line>\t<message>"; uses $root, $baseline, $now and $sgconfig from the caller.

comment_run_min=3    # the comments rule caps a comment at one line, so three lines of text in a row is a block
long_function_min=51 # past 50 lines a function rarely reads as a short list of named steps (ADR 0024)
grab_bag_names='^(utils?|helpers?|misc|stuff)$'
# A top-level type declaration at column 0, across the languages the gate reads; the name is its last word.
type_declaration='((export|public|internal|private|protected|data|sealed|enum|value|abstract|open|final|default|declare|static|pub(\([a-z]+\))?)[[:space:]]+)*(class|interface|object|enum|type|typealias|record|struct|trait|union)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*'
# Languages whose files declare types that way; shell's `type` builtin and docs would only add noise.
declaration_pathspecs=('*.kt' '*.kts' '*.java' '*.scala' '*.groovy' '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs'
  '*.go' '*.rs' '*.swift' '*.cs' '*.dart' '*.php' '*.py' ':!docs/')

# Turns RANGES (a "<first> <last>" per line) into an added(line) test inside awk.
ranges_awk='
  BEGIN { n = split(ENVIRON["RANGES"], r, "\n"); for (i = 1; i <= n; i++) { split(r[i], b, " "); lo[i] = b[1]; hi[i] = b[2] } }
  function added(l,   i) { for (i = 1; i <= n; i++) if (l >= lo[i] && l <= hi[i]) return 1; return 0 }
'
# A type alias such as `type Quote = carrier.Quote` names something declared elsewhere on purpose.
alias_awk='
  function alias(line) { return line ~ /=[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*(<[^=]*>)?[[:space:]]*;?[[:space:]]*$/ }
'

is_new() {
  ! git -C "$root" cat-file -e "$baseline:$1" 2>/dev/null
}

# "<first> <last>" for each run of lines the session added or changed in $1, whitespace aside; a new file is one run.
added_ranges() {
  if is_new "$1"; then
    printf '1 %s\n' "$(git -C "$root" cat-file -p "$now:$1" | awk 'END { print NR }')"
    return
  fi
  git -C "$root" diff-tree -p -U0 -w --no-renames "$baseline" "$now" -- ":(literal)$1" |
    sed -nE 's/^@@ -[0-9,]+ \+([0-9]+)(,([0-9]+))? @@.*/\1 \3/p' |
    awk '{ count = ($2 == "" ? 1 : $2); if (count > 0) print $1, $1 + count - 1 }'
}

# Wholly new comment runs with at least $comment_run_min lines of text; delimiter-only lines and license headers don't count.
comment_runs() {
  local path=$1 hash_comments=1 dash_comments=0
  case "${path##*/}" in
  *.c | *.h | *.cc | *.cpp | *.hpp | *.cs | *.m | *.mm | *.java | *.kt | *.kts | *.scala | *.groovy | *.gradle | *.js | \
    *.jsx | *.mjs | *.cjs | *.ts | *.tsx | *.go | *.rs | *.swift | *.dart | *.php | *.proto | *.vue | *.svelte | *.zig | \
    *.qml) hash_comments=0 ;;
  *.lua | *.sql | *.hs) hash_comments=0 dash_comments=1 ;;
  esac
  git -C "$root" cat-file -p "$now:$path" |
    RANGES=$2 FILE=$path awk -v min="$comment_run_min" -v hash="$hash_comments" -v dash="$dash_comments" "$ranges_awk"'
      function flush() {
        if (text >= min && fresh == run && !license)
          printf "fix\t%s\t%d\t%d-line comment block: the comments rule keeps a why to one line; compress it or delete it\n", ENVIRON["FILE"], start, text
        run = 0; text = 0; fresh = 0; license = 0
      }
      { line = $0; sub(/\r$/, "", line); sub(/^[[:space:]]+/, "", line)
        # A `*` line is a comment only inside /* */; elsewhere it can be a continued multiplication or a docstring bullet.
        if (in_block || line ~ /^\/\*/) { comment = 1; in_block = line !~ /\*\// }
        else comment = line ~ /^\/\// || (dash && line ~ /^--([ \t]|$)/) || (hash && line ~ /^#([ \t]|$)/)
        if (comment) {
          if (run == 0) start = NR
          run++; fresh += added(NR)
          if (line !~ /^(\/\*+|\*+\/|\*|#|\/\/|--)[[:space:]]*$/) text++
          if (tolower(line) ~ /copyright|licen[cs]e|spdx-/) license = 1
        } else flush() }
      END { flush() }
    '
}

grab_bag_name() {
  local stem=${1##*/}
  stem=${stem%.*}
  if is_new "$1" && [[ ${stem,,} =~ $grab_bag_names ]]; then
    printf 'fix\t%s\t1\tnamed like a grab-bag; name the file for its one concern, or split it by concern\n' "$1"
  fi
}

# Functions of at least $long_function_min lines that overlap what the session added; ast-grep reads the files on disk.
long_functions() {
  local -n added_by_path=$1
  local path first last head
  for path in "${!added_by_path[@]}"; do
    printf '%s\0' "$root/$path"
  done | xargs -0 ast-grep scan -c "$sgconfig" --json=stream -- |
    jq -j --arg root "$root/" '(.file | ltrimstr($root)), "\u0000", (.range.start.line + 1 | tostring), "\u0000",
      (.range.end.line + 1 | tostring), "\u0000", (.text | split("\n")[0] | gsub("^\\s+|\\s*[{=]?\\s*$"; "") | .[0:70]), "\u0000"' |
    while IFS= read -r -d '' path && IFS= read -r -d '' first && IFS= read -r -d '' last && IFS= read -r -d '' head; do
      if [[ -v added_by_path[$path] ]] && ((last - first + 1 >= long_function_min)) &&
        awk -v a="$first" -v b="$last" '$1 <= b && $2 >= a { found = 1 } END { exit !found }' <<<"${added_by_path[$path]}"; then
        # shellcheck disable=SC2016 # the backticks are markdown for the message
        printf 'look\t%s\t%s\t`%s` is %s lines: if it is not a short list of named steps, pull each step into a function named for it\n' \
          "$path" "$first" "$head" "$((last - first + 1))"
      fi
    done
}

# "<line>\t<name>" for each top-level type declaration on stdin that isn't an alias; with an argument, only lines in RANGES.
type_names() {
  TYPES="^$type_declaration" ONLY_ADDED=${1:-} awk "$ranges_awk$alias_awk"'
    (ENVIRON["ONLY_ADDED"] == "" || added(NR)) && match($0, ENVIRON["TYPES"]) && !alias($0) {
      n = split(substr($0, 1, RLENGTH), w, /[[:space:]]+/); print NR "\t" w[n] }'
}

# "<name>\t<path>" for every top-level type declaration in the snapshot.
declaration_index() {
  { git -C "$root" grep -z -I -E "^$type_declaration" "$now" -- "${declaration_pathspecs[@]}" || true; } |
    TYPES="^$type_declaration" awk -F'\0' -v prefix="${#now}" "$alias_awk"'
      { path = substr($1, prefix + 2); line = $2
        if (match(line, ENVIRON["TYPES"]) && !alias(line)) { n = split(substr(line, 1, RLENGTH), w, /[[:space:]]+/); print w[n] "\t" path } }'
}

# New top-level type names that another file already declares: one concept, one name. $3 is the declaration index.
name_collisions() {
  local path=$1 index=$3 earlier="" line name others
  if ! is_new "$path"; then
    earlier=$(git -C "$root" cat-file -p "$baseline:$path" | type_names | cut -f2)
  fi
  git -C "$root" cat-file -p "$now:$path" | RANGES=$2 type_names added |
    while IFS=$'\t' read -r line name; do
      # A type the file declared before the session isn't a new name.
      if grep -qxF -- "$name" <<<"$earlier"; then
        continue
      fi
      others=$(awk -F'\t' -v name="$name" -v self="$path" '$1 == name && $2 != self { print $2 }' <<<"$index" |
        LC_ALL=C sort -u | sed -n 1,3p | paste -sd, -)
      if [ -n "$others" ]; then
        # shellcheck disable=SC2016 # the backticks are markdown for the message
        printf 'look\t%s\t%s\t`%s` is also declared in %s: if it is the same concept, use that one; if not, give one of them a name that says the difference\n' \
          "$path" "$line" "$name" "$others"
      fi
    done
}

# Every finding for the given changed code files, sorted so the same code always gives the same list.
findings_for() {
  local path ranges index found=""
  local -A added=()
  index=$(declaration_index)
  for path in "$@"; do
    ranges=$(added_ranges "$path")
    [ -n "$ranges" ] || continue
    added[$path]=$ranges
    found+=$(
      grab_bag_name "$path"
      comment_runs "$path" "$ranges"
      name_collisions "$path" "$ranges" "$index"
    )$'\n'
  done
  if ((${#added[@]})); then
    found+=$(long_functions added)
  fi
  { grep -v '^$' <<<"$found" || true; } | LC_ALL=C sort -t$'\t' -k2,2 -k3,3n
}
