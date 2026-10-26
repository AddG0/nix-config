# `opencode-skill-check <opencode> <skills-dir>`: fails naming each skill file opencode skips.
# opencode 2.x dropped `debug skill`; its server still loads skills and logs each one it skips.
{pkgs}:
pkgs.writeShellApplication {
  name = "opencode-skill-check";
  runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.jq];
  text = ''
    opencode=$1
    dir=$2
    [[ -d $dir ]] || exit 0

    # The files opencode's skill scan reads: SKILL.md in any subdirectory, plus top-level *.md.
    mapfile -t want < <({
      find -L "$dir" -mindepth 2 -name SKILL.md
      find -L "$dir" -maxdepth 1 -type f -name '*.md'
    } | xargs -r realpath | sort -u)
    [[ ''${#want[@]} -gt 0 ]] || exit 0

    log=$(mktemp)
    reply=$(mktemp)
    port=$((20000 + RANDOM % 20000))
    export OPENCODE_PASSWORD=skill-check
    "$opencode" serve --hostname 127.0.0.1 --port "$port" --print-logs --log-level debug >"$log" 2>&1 &
    server=$!
    trap 'kill "$server" 2>/dev/null || true' EXIT

    # Skills load in the background, so poll until every file is either listed or logged as skipped.
    for _ in $(seq 120); do
      sleep 0.5
      if ! kill -0 "$server" 2>/dev/null; then
        echo "opencode serve exited before loading skills:" >&2
        cat "$log" >&2
        exit 1
      fi
      # FLAKE-UPDATE: pipe straight to jq again once `opencode api` stops cutting piped replies at a 4 KiB boundary (opencode 2.1.1).
      "$opencode" api --server "http://127.0.0.1:$port" skill.list >"$reply" 2>/dev/null || continue
      listed=$(jq -r '.data[].path' "$reply" 2>/dev/null) || continue
      listed=$(xargs -r realpath -q <<<"$listed" 2>/dev/null || true)
      # "<resolved path> <reason...>" for each skip opencode has logged so far.
      skips=$(grep -F 'message="skill file skipped"' "$log" | sed -E 's/.* filepath=([^ ]+) (.*)/\1 \2/' |
        while read -r path reason; do printf '%s %s\n' "$(realpath -q "$path" || echo "$path")" "$reason"; done || true)
      unresolved=()
      skipped=()
      for file in "''${want[@]}"; do
        if grep -qxF -- "$file" <<<"$listed"; then
          continue
        elif reason=$(grep -F -- "$file " <<<"$skips" | head -1) && [[ -n $reason ]]; then
          skipped+=("$reason")
        else
          unresolved+=("$file")
        fi
      done
      [[ ''${#unresolved[@]} -eq 0 ]] || continue
      if [[ ''${#skipped[@]} -gt 0 ]]; then
        echo "opencode skipped these skill files:" >&2
        printf '  %s\n' "''${skipped[@]}" >&2
        exit 1
      fi
      exit 0
    done

    echo "opencode neither loaded nor skipped these skill files within 60 s:" >&2
    printf '  %s\n' "''${unresolved[@]}" >&2
    exit 1
  '';
}
