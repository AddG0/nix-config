#!/usr/bin/env bash
# nvim-uri-handler <uri>
#
# Scheme handler for nvim://file/<path>:<line>:<column> — the "Open in Editor"
# target for React DevTools, which fires the URL through window.open(), so the
# jump has to arrive as an OS scheme handler rather than a shell command.
#
# Reuse needs no --listen bookkeeping: every running nvim already listens on
# $XDG_RUNTIME_DIR/nvim.<pid>.0.
set -euo pipefail

uri=${1:-}
[[ -n $uri ]] || {
  echo "nvim-uri-handler: missing uri" >&2
  exit 1
}

target=${uri#nvim://}
target=${target#file/}
# minimal percent-decode
target=$(printf '%b' "${target//%/\\x}")

line=1
col=1
if [[ $target =~ ^(.+):([0-9]+):([0-9]+)$ ]]; then
  path=${BASH_REMATCH[1]}
  line=${BASH_REMATCH[2]}
  col=${BASH_REMATCH[3]}
elif [[ $target =~ ^(.+):([0-9]+)$ ]]; then
  path=${BASH_REMATCH[1]}
  line=${BASH_REMATCH[2]}
else
  path=$target
fi

# DevTools substitutes an absolute path into `file/{path}`, yielding `//home/...`.
while [[ $path == //* ]]; do path=${path#/}; done

[[ -f $path ]] || {
  notify-send -u critical "nvim-uri-handler" "Not a file: $path"
  echo "nvim-uri-handler: not a file: $path" >&2
  exit 1
}

# Longest matching cwd wins, so a gwq worktree beats the checkout it branched from.
server=
server_cwd=
for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*; do
  [[ -S $sock ]] || continue
  cwd=$(timeout 2 nvim --server "$sock" --remote-expr 'getcwd()' 2>/dev/null) || continue
  [[ -n $cwd ]] || continue
  # Trailing slash anchors on a path boundary: `…/NewDashboard` must not claim
  # `…/NewDashboard--ENG26-1714/src/App.tsx`.
  if [[ $path == "$cwd"/* && ${#cwd} -gt ${#server_cwd} ]]; then
    server=$sock
    server_cwd=$cwd
  fi
done

if [[ -z $server ]]; then
  # No running nvim owns this file, so it's either a project you don't have open
  # or a rogue nvim:// link — confirm before spawning a window. Unlike
  # glmr-open's fields, $path is any existing path, so escape Pango markup to
  # stop a crafted filename impersonating dialog chrome.
  shown=${path//&/&amp;}
  shown=${shown//</&lt;}
  rc=0
  yad --title="nvim-uri-handler" --image=dialog-question \
    --button=Cancel:1 --button=Open:0 \
    --text="Open in a new Neovim window?

$shown:$line:$col" || rc=$?
  if [[ $rc != 0 ]]; then
    # 1 = Cancel, 252 = closed via ESC/WM. Anything else is yad itself failing,
    # which has to be loud — a broken dialog must not read as a silent decline.
    [[ $rc == 1 || $rc == 252 ]] && exit 0
    notify-send -u critical "nvim-uri-handler" "Confirmation dialog failed (yad $rc); not opening"
    echo "nvim-uri-handler: confirmation dialog failed (yad exit $rc)" >&2
    exit 1
  fi

  exec ghostty --title=nvim-uri-handler -e \
    nvim "+call cursor($line, $col)" -- "$path"
fi

# Separate calls, not one composed :execute — keeps the path an argv element, so
# quotes in filenames survive.
nvim --server "$server" --remote-expr 'execute("tabfirst")' >/dev/null
nvim --server "$server" --remote "$path"
nvim --server "$server" --remote-expr "cursor($line, $col)" >/dev/null

# Everything below only raises the window the jump landed in; the edit is already
# done, so every step is best-effort.
command -v hyprctl >/dev/null || exit 0
pid=${server##*/nvim.}
pid=${pid%%.*}
[[ $pid =~ ^[0-9]+$ ]] || exit 0

ancestors=()
p=$pid
while [[ -n $p && $p != 1 ]]; do
  ancestors+=("$p")
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ') || break
done

# Hyprland tracks the terminal's pid, not nvim's, so look up the whole chain.
declare -A window_of
while read -r wpid waddr; do window_of[$wpid]=$waddr; done < <(
  hyprctl clients -j | jq -r '.[] | "\(.pid) \(.address)"'
)

addr=
for p in "${ancestors[@]}"; do
  if [[ -n ${window_of[$p]-} ]]; then
    addr=${window_of[$p]}
    break
  fi
done

# tmux from PATH, not runtimeInputs: a client only talks to a same-build server.
if [[ -z $addr ]] && command -v tmux >/dev/null; then
  # Under tmux the server is reparented to systemd, so nvim's ancestry never reaches
  # a terminal — go sideways: find its pane, then follow the session's attached
  # client back out to a window.
  declare -A pane_of
  while read -r ppid pane; do pane_of[$ppid]=$pane; done < <(
    tmux list-panes -a -F '#{pane_pid} #{session_name}:#{window_index}.#{pane_index}' 2>/dev/null
  )
  pane=
  for p in "${ancestors[@]}"; do
    if [[ -n ${pane_of[$p]-} ]]; then
      pane=${pane_of[$p]}
      break
    fi
  done

  if [[ -n $pane ]]; then
    tmux select-window -t "${pane%.*}" 2>/dev/null || true
    tmux select-pane -t "$pane" 2>/dev/null || true
    declare -A client_of
    while read -r cpid csession; do client_of[$csession]=$cpid; done < <(
      tmux list-clients -F '#{client_pid} #{client_session}' 2>/dev/null
    )
    client=${client_of[${pane%%:*}]-}
    [[ -n $client ]] && addr=${window_of[$client]-}
  fi
fi

[[ -n $addr ]] && hyprctl dispatch focuswindow "address:$addr" >/dev/null
exit 0
