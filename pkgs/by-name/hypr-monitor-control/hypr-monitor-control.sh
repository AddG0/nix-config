# shellcheck shell=bash
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-monitor-control"
mkdir -p "$state_dir"

if [[ -t 1 ]] && [[ -z ${NO_COLOR:-} ]]; then
  c_ok=$'\033[32m'
  c_err=$'\033[31m'
  c_dim=$'\033[2m'
  c_reset=$'\033[0m'
else
  c_ok=""
  c_err=""
  c_dim=""
  c_reset=""
fi

ok() { printf '%s✓%s %s\n' "$c_ok" "$c_reset" "$*"; }
skip() { printf '%s•%s %s\n' "$c_dim" "$c_reset" "$*" >&2; }
err() { printf '%s✗%s %s\n' "$c_err" "$c_reset" "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: hypr-monitor-control <subcommand> [name...]

Subcommands:
  list                List monitors known to Hyprland and their state.
  disable <name...>   Save current spec then disable the monitor(s).
                      Refuses the last active monitor; -f to force.
  enable <name...>    Re-enable using saved spec, else preferred,auto.
  toggle <name...>    Disable if active, enable if disabled.
  rate <name> <hz>    Switch an active monitor's refresh rate, keeping
                      the rest of its live layout.
  recover             Re-apply declared layout and reflow workspaces.
                      Use when runtime state is wedged (hot-plug
                      glitch, crashed sunshine session, etc).
EOF
}

active_names() {
  hyprctl monitors -j | jq -r '.[].name'
}

all_names() {
  hyprctl monitors all -j | jq -r '.[].name'
}

is_active() {
  hyprctl monitors -j | jq -e --arg n "$1" 'map(select(.name == $n)) | length > 0' >/dev/null
}

active_count() {
  hyprctl monitors -j | jq 'length'
}

# Known to Hyprland at all (active or configured-disabled).
is_known() {
  hyprctl monitors all -j | jq -e --arg n "$1" 'any(.[]; .name == $n)' >/dev/null
}

# Hint listing every name Hyprland currently reports, for typos.
known_hint() {
  local names
  names=$(all_names | tr '\n' ' ')
  [[ -n $names ]] && echo "  known monitors: $names" >&2 || true
}

# Full monitor keyword spec for active monitor $1, at refresh rate $2 if given (else its current one).
# Covers resolution, position, scale, transform, VRR, 10-bit and HDR; mirror and custom modes aren't in hyprctl JSON.
spec_for() {
  hyprctl monitors -j | jq -r --arg n "$1" --arg rate "${2:-}" '
    .[] | select(.name == $n)
    | "\(.name),\(.width)x\(.height)@\(if $rate == "" then .refreshRate + 0 else $rate end),\(.x)x\(.y),\(.scale + 0),transform,\(.transform),vrr,\(if .vrr then 1 else 0 end)"
      + (if (.currentFormat // "") | test("10") then ",bitdepth,10" else "" end)
      + (if (.colorManagementPreset // "") == "hdr" then ",cm,hdr" else "" end)
  '
}

save_spec() {
  local spec
  spec=$(spec_for "$1")
  if [[ -n $spec ]]; then
    printf '%s\n' "$spec" >"$state_dir/$1.spec"
  fi
}

# Apply a monitor keyword spec, swallowing hyprctl's raw "ok" and
# surfacing any error under our own formatting. $1 = monitor name
# (for messages), $2 = full keyword spec.
apply_spec() {
  local out
  out=$(hyprctl keyword monitor "$2" 2>&1)
  if [[ $out == "ok" ]]; then
    return 0
  fi
  err "$1: ${out:-hyprctl failed}"
  return 1
}

do_disable() {
  # Refuse to black out the last display unless forced — recovering
  # from zero active monitors means blind keybinds or a TTY.
  if [[ ${force:-0} != 1 ]] && (($(active_count) <= 1)); then
    err "$1 is the last active monitor; refusing (use 'disable -f' to force)"
    return 1
  fi
  save_spec "$1"
  apply_spec "$1" "$1,disable" || return 1
  ok "$1 disabled"
}

do_enable() {
  local name="$1"
  local spec_file="$state_dir/$name.spec"
  if [[ -s $spec_file ]]; then
    apply_spec "$name" "$(cat "$spec_file")" || return 1
    ok "$name enabled (restored saved layout)"
  else
    # No saved state — fall back to Hyprland's preferred mode and
    # let auto-positioning pick a column to the right of existing
    # outputs. Works for fresh hot-plug; user can `hypr-monitor-control recover`
    # afterwards to re-establish the declared layout.
    apply_spec "$name" "$name,preferred,auto,1" || return 1
    ok "$name enabled (preferred mode, auto-positioned)"
  fi
}

do_recover() {
  # shellcheck disable=SC2154 # set by package.nix ahead of this script
  if [[ $declared_layout != 1 ]]; then
    err "no monitors declared in config; recover is a no-op"
    echo "  use 'hypr-monitor-control enable <name>' for ad-hoc restore." >&2
    exit 1
  fi

  # Reload drops runtime monitor keywords and re-applies the declared monitorv2 rules.
  hyprctl reload
  sleep 2

  # Move configured workspaces back to their assigned monitors.
  local rule ws
  # shellcheck disable=SC2154 # set by package.nix ahead of this script
  for rule in "${workspace_monitors[@]}"; do
    hyprctl dispatch moveworkspacetomonitor "${rule%%:*}" "${rule#*:}"
  done

  # Sweep any remaining workspaces onto the primary monitor.
  if [[ -n $primary_monitor ]]; then
    for ws in $(hyprctl -j workspaces | jq -r '.[].id'); do
      if ! printf '%s\n' "${workspace_monitors[@]%%:*}" | grep -qx -- "$ws"; then
        hyprctl dispatch moveworkspacetomonitor "$ws" "$primary_monitor"
      fi
    done
  fi
  ok "monitors restored"
}

do_rate() {
  local name="$1" hz="$2"
  if ! is_active "$name"; then
    err "monitor '$name' is not active; cannot set it to ${hz}Hz"
    known_hint
    return 1
  fi
  apply_spec "$name" "$(spec_for "$name" "$hz")" || return 1
  ok "$name at ${hz}Hz"
}

cmd="${1:-}"

case "$cmd" in
list)
  # `monitors all` includes monitors currently configured as
  # disabled; the active set is `monitors`. Diff to label state.
  active=$(active_names | tr '\n' '|')
  while IFS=$'\t' read -r m model res; do
    if [[ "|$active|" == *"|$m|"* ]]; then
      state="active"
      col="$c_ok"
    else
      state="disabled"
      col="$c_dim"
    fi
    # Pad before coloring so escape codes don't break alignment.
    printf -v statecol '%-8s' "$state"
    printf '%-12s %s%s%s  %s%s  %s\n' \
      "$m" "$col" "$statecol" "$c_reset" "$c_dim" "$model" "$res$c_reset"
  done < <(hyprctl monitors all -j | jq -r '
      .[] | "\(.name)\t\(.model // .description // "?")\t\(.width)x\(.height)@\(.refreshRate | floor)Hz"
    ')
  ;;
disable)
  shift
  force=0
  names=()
  for a in "$@"; do
    case "$a" in
    -f | --force) force=1 ;;
    *) names+=("$a") ;;
    esac
  done
  [[ ${#names[@]} -eq 0 ]] && {
    usage
    exit 1
  }
  rc=0
  for name in "${names[@]}"; do
    if is_active "$name"; then
      do_disable "$name" || rc=1
    elif is_known "$name"; then
      skip "$name already disabled"
    else
      err "unknown monitor '$name'"
      known_hint
      rc=1
    fi
  done
  exit "$rc"
  ;;
enable)
  [[ $# -lt 2 ]] && {
    usage
    exit 1
  }
  rc=0
  for name in "${@:2}"; do
    if is_active "$name"; then
      skip "$name already enabled"
    else
      do_enable "$name" || rc=1
    fi
  done
  exit "$rc"
  ;;
toggle)
  [[ $# -lt 2 ]] && {
    usage
    exit 1
  }
  rc=0
  for name in "${@:2}"; do
    if is_active "$name"; then
      do_disable "$name" || rc=1
    else
      do_enable "$name" || rc=1
    fi
  done
  exit "$rc"
  ;;
rate)
  [[ $# -ne 3 || ! $3 =~ ^[0-9]+([.][0-9]+)?$ ]] && {
    usage
    exit 1
  }
  do_rate "$2" "$3"
  ;;
recover)
  do_recover
  ;;
"" | -h | --help | help)
  usage
  ;;
*)
  usage
  exit 1
  ;;
esac
