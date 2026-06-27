# klnav [stern-flags] QUERY — tail matching pods into lnav, one file per
# namespace/pod/container so each is a separately toggleable source (TAB → Files
# panel → click the diamond, or :hide-file / :show-file). All args forward to
# stern, so -n <ns>, -A, -l <selector>, -c <container>, --no-follow, regex, etc.
# all work. KLNAV_TAIL overrides the per-pod line count (default 10).
dir=$(mktemp -d)
errlog=$(mktemp)
# pkill -P reaps both stern and awk; stern alone would linger when idle (no
# SIGPIPE without a write). EXIT also covers q / Ctrl-C out of lnav.
trap 'pkill -P $$ 2>/dev/null; rm -rf "$dir" "$errlog"' EXIT

has_files() {
  local f
  for f in "$dir"/*; do
    [ -e "$f" ] && return 0
  done
  return 1
}

# Route on explicit template fields (not positional columns) so multi-namespace
# output and same-named pods across namespaces don't collide. stern 1.34 has no
# .Timestamp field, so --timestamps prepends the RFC3339 time onto .Message and
# each file then leads with a time lnav can order by. --color never guards a
# forced-color stern config; status lines ("+ pod") go to stderr.
tmpl='{{.Namespace}}{{"\t"}}{{.PodName}}{{"\t"}}{{.ContainerName}}{{"\t"}}{{.Message}}{{"\n"}}'
# shellcheck disable=SC2016  # the awk program is single-quoted on purpose
stern --color never --timestamps --tail "${KLNAV_TAIL:-10}" --template "$tmpl" "$@" 2>"$errlog" |
  stdbuf -oL awk -F'\t' -v dir="$dir" '
      NF >= 4 {
        f = dir "/" $1 "." $2 "." $3 ".log"
        sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, "")
        print >> f
        fflush(f)
      }' &
pid=$!

# Give the first line ~5s to land before opening lnav (it watches the dir for
# files from pods that log later). If nothing arrives and stern already died,
# surface its error instead of opening an empty view.
for ((i = 0; i < 50; i++)); do
  has_files && break
  sleep 0.1
done
if ! has_files; then
  if kill -0 "$pid" 2>/dev/null; then
    printf 'klnav: matched pods, waiting for log lines...\n' >"$dir/klnav.status"
  else
    echo "klnav: stern exited without output:" >&2
    cat "$errlog" >&2
    exit 1
  fi
fi
lnav "$dir"
