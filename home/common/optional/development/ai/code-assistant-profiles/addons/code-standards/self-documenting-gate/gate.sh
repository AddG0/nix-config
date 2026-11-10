# Stop: run the mechanical self-documenting checks on code this session changed, holding the turn for what must be fixed.
# Uses state.sh (repo_root, baseline_file, snapshot_tree, record_baseline) and findings.sh (findings_for), both prepended.

hold() {
  jq -nc --arg r "$1" '{decision: "block", reason: $r}'
}

nudge() {
  jq -nc --arg c "$1" '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $c}}'
}

notice() {
  jq -nc --arg m "Self-documenting check: $1" '{systemMessage: $m}'
}

# A background agent may still be writing, so the turn is paused, not done.
paused_on_agents() {
  jq -e 'any(.background_tasks[]?; .type == "subagent" or .type == "workflow")' >/dev/null <<<"$input"
}

is_code() {
  local name=${1##*/}
  case "$1" in docs/*) return 1 ;; esac
  case "$name" in
  *.nix | *.sh | *.bash | *.zsh | *.fish | *.nu | *.bats | *.py | *.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs | \
    *.go | *.rs | *.kt | *.kts | *.java | *.scala | *.groovy | *.gradle | *.rb | *.lua | *.sql | *.proto | *.jq | \
    *.qml | *.c | *.h | *.cc | *.cpp | *.hpp | *.cs | *.swift | *.php | *.ex | *.exs | *.hs | *.ml | *.zig | *.dart | \
    *.clj | *.vue | *.svelte | *.tf) return 0 ;;
  *.*) return 1 ;;
  esac
  [ "$(head -c 2 "$root/$1" 2>/dev/null || true)" = '#!' ]
}

# The branch's remote upstream and each remote's default branch: content already there was written elsewhere.
# A local upstream, or a remote ref this machine last moved by pushing, holds the session's own work, so neither counts.
upstream_refs() {
  local upstream ref
  upstream=$(git -C "$root" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null || true) # no upstream is normal
  {
    case "$upstream" in refs/remotes/*) printf '%s\n' "$upstream" ;; esac
    git -C "$root" for-each-ref --format='%(symref)' 'refs/remotes/*/HEAD'
  } | while IFS= read -r ref; do
    if [ -n "$ref" ] &&
      [ "$(git -C "$root" reflog show -1 --no-show-signature --format=%gs "$ref" 2>/dev/null || true)" != "update by push" ]; then
      printf '%s\n' "$ref"
    fi
  done
}

from_upstream() {
  local ref
  for ref in "${upstream[@]}"; do
    # An empty ref would read "$ref:$1" as the index, which holds this session's own staged work.
    [ -n "$ref" ] || continue
    if [ "$(git -C "$root" rev-parse -q --verify "$ref:$1" 2>/dev/null || true)" = "$2" ]; then
      return 0
    fi
  done
  return 1
}

# Code files added or modified between the baseline and the snapshot, one per line.
changed_code_files() {
  local list refs meta path mode blob
  list=$(mktemp)
  # shellcheck disable=SC2064 # expanded now: $list is local and gone when the trap runs
  trap "rm -f -- ${list@Q}" EXIT # runs in the $(...) subshell
  git -C "$root" diff-tree -r -z --no-renames --diff-filter=d "$baseline" "$now" >"$list"
  refs=$(upstream_refs)
  mapfile -t upstream <<<"$refs"
  while IFS= read -r -d '' meta && IFS= read -r -d '' path; do
    read -r _ mode _ blob _ <<<"$meta"
    case "$mode" in 120000 | 160000) continue ;; esac # a symlink or a submodule pointer, not code to read
    if is_code "$path" && ! from_upstream "$path" "$blob"; then
      printf '%s\n' "$path"
    fi
  done <"$list"
}

# "path:line  message" lines for one kind of finding.
listed() {
  awk -F'\t' -v kind="$1" '$1 == kind { printf "  %s:%s  %s\n", $2, $3, $4 }' <<<"$findings"
}

report() {
  local fixes looks
  fixes=$(listed fix)
  looks=$(listed look)
  printf 'Self-documenting check on code this session changed in %s.\n' "$root"
  if [ -n "$fixes" ]; then
    printf 'Fix:\n%s\n' "$fixes"
  fi
  if [ -n "$looks" ]; then
    printf 'Look, and leave it if it already reads right:\n%s\n' "$looks"
  fi
}

input=$(cat)
session=$(jq -er '.session_id' <<<"$input")
cwd=$(jq -er '.cwd' <<<"$input")
continuing=$(jq -r '.stop_hook_active // false' <<<"$input")

if paused_on_agents; then
  exit 0
fi
root=$(repo_root "$cwd") || {
  [ $? = 1 ] && exit 0
  exit 1
}
if [ "$(git -C "$root" config --get self-documenting.gate || true)" = off ]; then
  exit 0
fi
baseline_record=$(baseline_file "$root" "$session")
held="$baseline_record.held"

baseline=$(head -n 1 "$baseline_record" 2>/dev/null || true)
if [ -z "$baseline" ] || ! git -C "$root" cat-file -e "$baseline" 2>/dev/null; then
  record_baseline "$root" "$session"
  notice "no baseline for $root in this session, so its changes count from now."
  exit 0
fi

now=$(snapshot_tree "$root" "$session")
changed=$(changed_code_files)
if [ -z "$changed" ]; then
  rm -f "$held"
  exit 0
fi
mapfile -t changed_paths <<<"$changed"
findings=$(findings_for "${changed_paths[@]}")
if [ -z "$findings" ]; then
  rm -f "$held"
  exit 0
fi

# Without line numbers or counts, so an edit above a finding, or one more line in it, doesn't make it look new.
seen=$(cut -f1,2,4 <<<"$findings" | sed -E 's/[0-9]+/N/g' | LC_ALL=C sort)
if [ -f "$held" ] && [ "$(<"$held")" = "$seen" ]; then
  # Shown once already: if Claude stopped again without fixing what it had to, say so; otherwise stay quiet.
  if [ "$continuing" = true ] && [ -n "$(listed fix)" ]; then
    notice "the turn ended with these unfixed:
$(listed fix)"
  fi
  exit 0
fi
printf '%s\n' "$seen" >"$held"
if [ -n "$(listed fix)" ]; then
  hold "$(report)"
else
  nudge "$(report)"
fi
