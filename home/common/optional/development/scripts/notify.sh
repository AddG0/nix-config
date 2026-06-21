#!/usr/bin/env bash
# notify — run a command and send a desktop notification when it finishes.
# Cross-platform: Linux uses notify-send (libnotify), macOS uses
# terminal-notifier (with an osascript fallback).
#
# Usage:
#   notify <command> [args...]   run a command, notify on completion
#   notify -m TITLE [BODY]       send a one-off notification and exit

if [ "$#" -eq 0 ]; then
  echo "usage: notify <command> [args...]" >&2
  echo "       notify -m TITLE [BODY]" >&2
  exit 64
fi

# Human-friendly elapsed time: "5s", "2m 03s", "1h 04m 09s".
fmt_duration() {
  local s="$1"
  if [ "$s" -ge 3600 ]; then
    printf '%dh %02dm %02ds' "$((s / 3600))" "$(((s % 3600) / 60))" "$((s % 60))"
  elif [ "$s" -ge 60 ]; then
    printf '%dm %02ds' "$((s / 60))" "$((s % 60))"
  else
    printf '%ds' "$s"
  fi
}

# send <title> <body> <status: ok|error|info>
# Status drives a proper notification icon/urgency instead of inline emoji,
# which renders inconsistently across notification daemons.
send() {
  local title="$1" body="$2" status="$3"
  case "$(uname -s)" in
  Darwin)
    if command -v terminal-notifier >/dev/null 2>&1; then
      local args=(-title "$title" -message "$body")
      [ "$status" = "error" ] && args+=(-sound Basso)
      terminal-notifier "${args[@]}"
    else
      # Escape double quotes for AppleScript string literals.
      osascript -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\""
    fi
    ;;
  *)
    local icon urgency
    case "$status" in
    ok)
      icon="emblem-ok"
      urgency="normal"
      ;;
    error)
      icon="dialog-error"
      urgency="critical"
      ;;
    *)
      icon="dialog-information"
      urgency="normal"
      ;;
    esac
    notify-send --app-name=notify --icon="$icon" --urgency="$urgency" "$title" "$body"
    ;;
  esac
}

# One-off message mode.
if [ "$1" = "-m" ]; then
  shift
  send "${1:-Notification}" "${2:-}" "info"
  exit 0
fi

# Command mode: run, time it, and report success/failure.
# `|| code=$?` keeps writeShellApplication's `set -e` from aborting on a
# non-zero command before we get to notify.
SECONDS=0
code=0
"$@" || code=$?
elapsed="$(fmt_duration "$SECONDS")"

cmd="$*"
if [ "$code" -eq 0 ]; then
  send "Command finished" "$cmd
Took $elapsed" "ok"
else
  send "Command failed — exit $code" "$cmd
Took $elapsed" "error"
fi

exit "$code"
