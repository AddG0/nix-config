# Echo stdin lines, dropping any monitor name in $1 (space-separated
# names already on the command line).
_monitor_prune() {
  local present=" $1 " n
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    case "$present" in *" $n "*) continue ;; esac
    printf '%s\n' "$n"
  done
}

_monitor_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local subcmd="${COMP_WORDS[1]}"
  local subcmds="list disable enable toggle rate recover"

  if [ "$COMP_CWORD" -eq 1 ]; then
    mapfile -t COMPREPLY < <(compgen -W "$subcmds" -- "$cur")
    return 0
  fi

  # Names already given as earlier positional args, to prune from
  # candidates so completing several monitors doesn't re-offer them.
  local i already=""
  for ((i = 2; i < COMP_CWORD; i++)); do
    already+=" ${COMP_WORDS[i]}"
  done

  case "$subcmd" in
  rate)
    if ((COMP_CWORD == 2)); then
      mapfile -t COMPREPLY < <(compgen -W "$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name')" -- "$cur")
    fi
    ;;
  disable | toggle)
    local mons
    mons=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name')
    mons=$(printf '%s\n' "$mons" | _monitor_prune "$already")
    mapfile -t COMPREPLY < <(compgen -W "$mons" -- "$cur")
    ;;
  enable)
    local mons active
    mons=$(hyprctl monitors all -j 2>/dev/null | jq -r '.[] | select(.disabled == true) | .name')
    active=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' | tr '\n' '|')
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-monitor-control"
    if [ -d "$state_dir" ]; then
      local f n
      for f in "$state_dir"/*.spec; do
        [ -e "$f" ] || continue
        n=$(basename "$f" .spec)
        # Skip if currently active.
        case "|$active" in *"|$n|"*) continue ;; esac
        mons="$mons"$'\n'"$n"
      done
    fi
    mons=$(printf '%s\n' "$mons" | awk 'NF && !seen[$0]++')
    mons=$(printf '%s\n' "$mons" | _monitor_prune "$already")
    mapfile -t COMPREPLY < <(compgen -W "$mons" -- "$cur")
    ;;
  esac
}
complete -F _monitor_complete hypr-monitor-control
