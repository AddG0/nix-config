#!/usr/bin/env bash
# SessionStart hook: summarise this repo's engineering documentation once per session.

INPUT=$(cat) || true
[ -n "$INPUT" ] || exit 0

CWD=$(echo "$INPUT" | jq -r '.cwd // empty') || true
CWD="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
DOCS="$CWD/docs"

[ -d "$DOCS" ] || exit 0

# Space-separated document basenames in a directory, or empty.
docs_in() {
  [ -d "$1" ] || return 0
  find "$1" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null |
    sed 's/\.md$//' | sort | paste -sd' ' -
}

OUT=""

# Named, not inlined — the agent reads the file when the task needs it.
steering=$(docs_in "$DOCS/steering")
[ -n "$steering" ] && OUT="${OUT}  docs/steering/: ${steering} (project context — read before design work)"$'\n'

if [ -d "$DOCS/adr" ]; then
  n=$(find "$DOCS/adr" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l)
  if [ "$n" -gt 0 ]; then
    noun="ADRs"
    [ "$n" -eq 1 ] && noun="ADR"
    OUT="${OUT}  docs/adr/: ${n} ${noun}"$'\n'
  fi
fi

for d in "$DOCS"/work/*/; do
  [ -d "$d" ] || continue
  found=$(docs_in "$d")
  [ -n "$found" ] || continue
  OUT="${OUT}  $(basename "$d"): ${found}"$'\n'
done

if [ -n "$OUT" ]; then
  printf 'Engineering docs in this repo:\n%s' "$OUT"
  printf 'Read the relevant ones before adding to them. /notes-status for detail.\n'
fi
