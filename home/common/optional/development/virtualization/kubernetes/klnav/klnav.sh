#!/usr/bin/env bash
# klnav [stern-flags] QUERY [QUERY...] — tail every matching pod into lnav, one
# file per namespace/pod/container so each is a separately toggleable source
# (TAB → Files panel → click the diamond, or :hide-file / :show-file).
#
# stern takes one pod-query and silently ignores extra positionals, so klnav
# runs one stern per query and merges them. A bare `<kind>/` expands to every
# object of that kind; `pod/` becomes a match-everything regex, since stern
# silently matches nothing for a resource query with an empty name. A pod
# matched by several queries is tailed once, not duplicated.

usage() {
  cat <<'EOF'
usage: klnav [stern-flags] QUERY [QUERY...]

Tails every pod matched by any QUERY into a single lnav view, one file per
namespace/pod/container. Flags are forwarded to stern verbatim.

  klnav -n prod pod/                      every pod in the namespace
  klnav -n prod deploy/api deploy/worker  two deployments, merged
  klnav -A pod/ -l app=nginx              all namespaces, label-filtered
  klnav -n prod deployment/               every deployment in the namespace
  klnav -n prod,staging pod/ job/nightly  mix of kinds and namespaces

Env: KLNAV_TAIL   lines of backlog per pod (default 10)
EOF
}

die() {
  echo "klnav: $1" >&2
  exit 1
}

[ $# -eq 0 ] && {
  usage >&2
  exit 1
}

# stern's flag table, read from the binary so it can't drift: pflag prints a type
# token after value-taking flags, nothing after booleans. `--timestamps
# string[="default"]` misses the whitelist on purpose — it only takes =value.
declare -A long_val=()
declare -A short_val=()
while IFS='|' read -r short long; do
  [ -n "$long" ] && long_val["$long"]=1
  [ -n "$short" ] && short_val["$short"]=1
done < <({
  stern --help
  stern --show-hidden-options
} 2>&1 |
  awk -v types='^(string|strings|stringArray|stringSlice|int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|bool|duration|durationSlice|ints|intSlice|count|ip|ipMask|ipNet|bytesHex|bytesBase64|stringToString|stringToInt|stringToInt64)$' '
    {
      l = ""
      if ($1 ~ /^-[A-Za-z],$/ && $2 ~ /^--/) { s = substr($1, 2, 1); l = substr($2, 3); t = $3 }
      else if ($1 ~ /^--/)                   { s = "";               l = substr($1, 3); t = $2 }
      if (l != "" && t ~ types) print s "|" l
    }')

# Splitting on stern's own flag table is what keeps `-n prod` from being read as
# the query "prod".
declare -a flags=()
declare -a queries=()
while (($#)); do
  case $1 in
  --)
    shift
    queries+=("$@")
    break
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --*=*) flags+=("$1") ;;
  --*)
    flags+=("$1")
    if [ -n "${long_val[${1#--}]:-}" ] && [ $# -gt 1 ]; then
      flags+=("$2")
      shift
    fi
    ;;
  -[!-]*)
    # Short cluster: only a value-taking flag with nothing after it in the
    # cluster reaches for the next argv element (-Ac ctr, but not -cctr).
    flags+=("$1")
    rest=${1#-}
    want=0
    while [ -n "$rest" ]; do
      ch=${rest:0:1}
      rest=${rest:1}
      if [ -n "${short_val[$ch]:-}" ]; then
        [ -z "$rest" ] && want=1
        break
      fi
    done
    if [ "$want" = 1 ] && [ $# -gt 1 ]; then
      flags+=("$2")
      shift
    fi
    ;;
  *) queries+=("$1") ;;
  esac
  shift
done

# Pull the namespaces back out: stern's completer errors on multiple namespaces
# and on -A, so a bare `<kind>/` has to be enumerated one namespace at a time.
declare -a base_flags=()
declare -a namespaces=()
all_ns=0
add_ns() {
  local IFS=','
  local n
  # shellcheck disable=SC2086  # splitting on the comma of -n a,b is the point
  for n in $1; do namespaces+=("$n"); done
}
for ((i = 0; i < ${#flags[@]}; i++)); do
  case ${flags[i]} in
  -A | --all-namespaces)
    all_ns=1
    base_flags+=("${flags[i]}")
    ;;
  --namespace=*) add_ns "${flags[i]#--namespace=}" ;;
  -n | --namespace)
    i=$((i + 1))
    add_ns "${flags[i]:-}"
    ;;
  -n?*) add_ns "${flags[i]#-n}" ;;
  *) base_flags+=("${flags[i]}") ;;
  esac
done

# Each target carries the one namespace it must be tailed in ("" = leave the
# user's own flags alone).
declare -a targets=()
declare -a target_ns=()
add_target() {
  targets+=("$1")
  target_ns+=("${2-}")
}

ns_flags() {
  if [ -n "$1" ]; then
    printf '%s\0' "${base_flags[@]}" -n "$1"
  elif [ ${#flags[@]} -gt 0 ]; then
    printf '%s\0' "${flags[@]}"
  fi
}

# Keep cobra's trailing `:N` — `:1` means the lookup failed, not that nothing matched.
enumerate() { # $1 = namespace override, $2 = "<kind>/" query
  local -a cf=()
  mapfile -t -d '' cf < <(ns_flags "$1")
  stern __complete "${cf[@]}" "$2" 2>>"$errlog"
}

dir=$(mktemp -d)
claimdir=$(mktemp -d)
errlog=$(mktemp)
# pkill -P reaps every stern and awk; stern alone would linger when idle (no
# SIGPIPE without a write). EXIT also covers q / Ctrl-C out of lnav.
trap 'pkill -P $$ 2>/dev/null; rm -rf "$dir" "$claimdir" "$errlog"' EXIT

# One namespace needs no override — the user's own -n already says it.
declare -a ns_list=("")
[ ${#namespaces[@]} -gt 1 ] && ns_list=("${namespaces[@]}")
declare -a comp=()
for q in "${queries[@]}"; do
  case $q in
  po/ | pod/ | pods/) add_target "." ;;
  */)
    if [ "$all_ns" = 1 ]; then
      die "'$q' cannot be expanded across all namespaces; name it, use pod/, or pass -n <namespace>"
    fi
    n=0
    for ns in "${ns_list[@]}"; do
      mapfile -t comp < <(enumerate "$ns" "$q")
      for c in "${comp[@]}"; do
        case $c in
        :1)
          echo "klnav: could not list '$q'${ns:+ in $ns}:" >&2
          grep -v '^Completion ended' "$errlog" >&2
          exit 1
          ;;
        :*) ;;
        *)
          add_target "${c%%$'\t'*}" "$ns"
          n=$((n + 1))
          ;;
        esac
      done
    done
    [ "$n" = 0 ] && die "no '$q' objects exist${namespaces[*]:+ in ${namespaces[*]}}"
    ;;
  *) add_target "$q" ;;
  esac
done

has_logs() {
  local f
  for f in "$dir"/*.log; do
    [ -e "$f" ] && return 0
  done
  return 1
}

# One stern failing must not be swallowed because the others are fine. awk opens
# the file lazily, so it only appears when there is something to say.
stdbuf -oL tail -f -n +1 "$errlog" 2>/dev/null |
  stdbuf -oL awk -v f="$dir/klnav.errors" '/^Error:/ { print >> f; fflush(f) }' &

# Route on explicit template fields (not positional columns) so multi-namespace
# output and same-named pods across namespaces don't collide. stern 1.34 has no
# .Timestamp field, so --timestamps prepends the RFC3339 time onto .Message and
# each file then leads with a time lnav can order by. --color never guards a
# forced-color stern config; status lines ("+ pod") go to stderr.
tmpl='{{.Namespace}}{{"\t"}}{{.PodName}}{{"\t"}}{{.ContainerName}}{{"\t"}}{{.Message}}{{"\n"}}'

# Overlapping queries (pod/ alongside deploy/api) hand the same pod to two
# sterns; mkdir is the atomic claim that keeps one copy, not two interleaved.
# shellcheck disable=SC2016  # $1..$3 are awk fields, not shell positionals
route='
  NF >= 4 && $1 ~ ok && $2 ~ ok && $3 ~ ok {
    key = $1 "." $2 "." $3
    if (!(key in mine))
      mine[key] = (system("mkdir " claim "/" key " 2>/dev/null") == 0)
    out = mine[key] ? dir "/" key ".log" : ""
    if (out == "") next
    sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, "")
    print >> out
    fflush(out)
    next
  }
  # A message carrying an embedded newline lands here; keep it with its record.
  out != "" { print >> out; fflush(out) }'

declare -a pids=()
spawn() { # $1 = namespace override, $2 = query (omitted for a bare -l run)
  local -a nf=()
  mapfile -t -d '' nf < <(ns_flags "$1")
  shift
  # Ours last: cobra is last-wins, and a user -o/--color would break the routing.
  stern --timestamps --tail "${KLNAV_TAIL:-10}" "${nf[@]}" \
    --color never --template "$tmpl" "$@" 2>>"$errlog" |
    stdbuf -oL awk -F'\t' -v dir="$dir" -v claim="$claimdir" \
      -v ok='^[A-Za-z0-9._-]+$' "$route" &
  pids+=("$!")
}

if [ ${#targets[@]} -eq 0 ]; then
  spawn "" # no query: -l / --field-selector / --prompt, or stern's own error
else
  for ((i = 0; i < ${#targets[@]}; i++)); do
    spawn "${target_ns[i]}" "${targets[i]}"
  done
fi

# Give the first line ~5s to land before opening lnav (it watches the dir for
# files from pods that log later). If nothing arrives and every stern already
# died, surface their errors instead of opening an empty view.
for ((i = 0; i < 50; i++)); do
  has_logs && break
  sleep 0.1
done
if ! has_logs; then
  alive=0
  for p in "${pids[@]}"; do
    kill -0 "$p" 2>/dev/null && alive=1
  done
  if [ "$alive" = 1 ]; then
    printf 'klnav: matched pods, waiting for log lines...\n' >"$dir/klnav.status"
  else
    if grep -qvE '^[+-] ' "$errlog"; then
      echo "klnav: stern produced no output:" >&2
      grep -vE '^[+-] ' "$errlog" >&2
    else
      echo "klnav: no pods matched${queries[*]:+: ${queries[*]}}" >&2
    fi
    exit 1
  fi
fi
lnav "$dir"
