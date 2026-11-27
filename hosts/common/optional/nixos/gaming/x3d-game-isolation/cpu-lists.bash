# CPU lists as the kernel and systemd write them ("0-3,16-19"): expand, compress, subtract and check them.

# expand_cpus <list>: one CPU number per line.
expand_cpus() {
  local part IFS=,
  for part in $1; do
    if [[ $part == *-* ]]; then seq "${part%-*}" "${part#*-}"; else echo "$part"; fi
  done
}

# compress_cpus: CPU numbers on stdin, in any order, as one list.
compress_cpus() {
  sort -n -u | awk '
    function flush() { out = out (out == "" ? "" : ",") (start == prev ? start : start "-" prev) }
    NR == 1 { start = prev = $1; next }
    $1 == prev + 1 { prev = $1; next }
    { flush(); start = prev = $1 }
    END { if (NR) flush(); print out }'
}

# without_cpus <list> <removed>: the CPUs of <list> that are not in <removed>.
without_cpus() {
  comm -23 <(expand_cpus "$1" | sort) <(expand_cpus "$2" | sort) | compress_cpus
}

# within_cpus <inner> <outer>: whether every CPU of <inner> is in <outer>.
within_cpus() {
  [ -z "$(comm -23 <(expand_cpus "$1" | sort) <(expand_cpus "$2" | sort))" ]
}

# is_cpu_list <text>: a list of CPU numbers below 4096 without leading zeros, each range ascending.
is_cpu_list() {
  local n='(0|[1-9][0-9]{0,3})'
  [[ $1 =~ ^$n(-$n)?(,$n(-$n)?)*$ ]] || return 1
  awk -v list="$1" 'BEGIN {
    n = split(list, parts, ",")
    for (i = 1; i <= n; i++) {
      split(parts[i], r, "-")
      last = (r[2] == "" ? r[1] : r[2])
      if (r[1] + 0 > last + 0 || last + 0 >= 4096) exit 1
    }
  }'
}
