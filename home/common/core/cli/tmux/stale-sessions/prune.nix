# Staleness is measured from the saved last-used time, not session_created:
# continuum restores every session with a fresh creation time on each boot, so a
# session last used days ago has to keep the time written back then.
{
  writeShellApplication,
  coreutils,
  tmux,
}:
writeShellApplication {
  name = "tmux-prune-stale-sessions";
  runtimeInputs = [coreutils tmux];
  text = ''
    now=$EPOCHSECONDS
    stale_after=$((3 * 24 * 60 * 60))
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tmux/last-attached"

    # No delimiter is safe: outside a UTF-8 locale tmux rewrites control characters
    # in -F output to "_", even ones from the format string. Names can hold spaces
    # but never a newline, so the name goes last and one record per line holds.
    sessions=$(tmux list-sessions -F "#{session_created} #{session_attached} #{session_name}" 2>/dev/null) || exit 0

    # Bailing keeps the orphan sweep below from reading "cannot reach tmux" as
    # "every session is gone".
    [ -n "$sessions" ] || exit 0

    install -d -m 700 "$state_dir"

    declare -A busy
    while IFS= read -r name; do
      busy["$name"]=1
    done < <(tmux list-panes -a -f "#{!=:#{pane_current_command},#{b:default-shell}}" \
                               -F "#{session_name}" 2>/dev/null)

    declare -A live
    while IFS= read -r line; do
      created=''${line%% *}
      rest=''${line#* }
      attached=''${rest%% *}
      name=''${rest#* }

      # base64url: the standard alphabet emits "/", which would split the path.
      key=$(printf '%s' "$name" | basenc --base64url -w 0)
      live["$key"]=1

      # In use right now: restamp so the countdown starts when it goes quiet.
      if [ "$attached" != 0 ] || [ -n "''${busy[$name]:-}" ]; then
        printf '%s\n' "$now" > "$state_dir/$key"
        continue
      fi

      last_used=""
      if [ -r "$state_dir/$key" ]; then
        IFS= read -r last_used < "$state_dir/$key" || true
      fi
      # First sighting seeds from creation time, which also covers sessions
      # created detached.
      [ "$last_used" -gt 0 ] 2>/dev/null || last_used="$created"
      printf '%s\n' "$last_used" > "$state_dir/$key"

      [ $((now - last_used)) -gt "$stale_after" ] || continue
      # "=" forces an exact match; a bare -t also matches by prefix.
      if tmux kill-session -t "=$name"; then
        rm -f "$state_dir/$key"
      fi
    done <<< "$sessions"

    # Forget dead sessions: a reused name must not inherit a stale time and die
    # on sight.
    for f in "$state_dir"/*; do
      [ -e "$f" ] || continue
      [ -n "''${live[''${f##*/}]:-}" ] || rm -f "$f"
    done
  '';
}
