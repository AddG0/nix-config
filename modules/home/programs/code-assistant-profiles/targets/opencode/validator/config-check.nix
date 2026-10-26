# `opencode-config-check <opencode> <config-dir>`: fails naming each config problem opencode logs and each agent file it drops.
# opencode 2.x loads config leniently (`debug config` only lists sources), so ask its server what it actually loaded.
{pkgs}:
pkgs.writeShellApplication {
  name = "opencode-config-check";
  runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.jq];
  text = ''
    opencode=$1
    dir=$2
    [[ -d $dir ]] || exit 0

    # The agent IDs opencode derives from {agent,agents}/**/*.md and {mode,modes}/*.md, minus self-disabled files.
    mapfile -t want < <(for sub in agent agents mode modes; do
      [[ -d $dir/$sub ]] || continue
      depth=()
      [[ $sub == mode* ]] && depth=(-maxdepth 1)
      find -L "$dir/$sub" "''${depth[@]}" -type f -name '*.md' | while read -r file; do
        if sed -n '1{/^---$/!q};2,/^---$/p' "$file" | grep -qE '^disabled?: *true'; then continue; fi
        rel=''${file#"$dir/$sub/"}
        echo "''${rel%.md}"
      done
    done | sort -u)

    log=$(mktemp)
    reply=$(mktemp)
    port=$((20000 + RANDOM % 20000))
    export OPENCODE_PASSWORD=config-check
    "$opencode" serve --hostname 127.0.0.1 --port "$port" --print-logs --log-level warn >"$log" 2>&1 &
    server=$!
    trap 'kill "$server" 2>/dev/null || true' EXIT

    # Agents load in the background in one step; settled once every file is listed or the list stops changing.
    listed=""
    stable=0
    settled=false
    for _ in $(seq 120); do
      sleep 0.5
      if ! kill -0 "$server" 2>/dev/null; then
        echo "opencode serve exited before loading its config:" >&2
        cat "$log" >&2
        exit 1
      fi
      # FLAKE-UPDATE: pipe straight to jq again once `opencode api` stops cutting piped replies at a 4 KiB boundary (opencode 2.1.1).
      "$opencode" api --server "http://127.0.0.1:$port" agent.list >"$reply" 2>/dev/null || continue
      now=$(jq -r '.data[].id' "$reply" 2>/dev/null | sort) || continue
      [[ -n $now ]] || continue
      missing=()
      for id in "''${want[@]}"; do
        grep -qxF -- "$id" <<<"$now" || missing+=("$id")
      done
      if [[ ''${#missing[@]} -eq 0 ]]; then
        settled=true
        break
      fi
      if [[ $now == "$listed" ]]; then stable=$((stable + 1)); else stable=0; fi
      listed=$now
      if [[ $stable -ge 3 ]]; then
        settled=true
        break
      fi
    done
    if [[ $settled != true ]]; then
      echo "opencode did not finish loading its agents within 60 s" >&2
      exit 1
    fi

    status=0
    # "<source> <path>: <action>" for each diagnostic; opencode logs each one once per config read.
    problems=$(grep -F 'message="configuration normalization diagnostic"' "$log" |
      sed -E 's/.* source=([^ ]+) path=([^ ]+) kind=[^ ]+ action="([^"]*)".*/\1 \2: \3/' | sort -u || true)
    if [[ -n $problems ]]; then
      echo "opencode reported these configuration problems:" >&2
      while read -r problem; do printf '  %s\n' "$problem" >&2; done <<<"$problems"
      status=1
    fi
    if [[ ''${#missing[@]} -gt 0 ]]; then
      echo "opencode dropped these agent files, so their frontmatter doesn't decode:" >&2
      printf '  %s\n' "''${missing[@]}" >&2
      status=1
    fi
    exit "$status"
  '';
}
