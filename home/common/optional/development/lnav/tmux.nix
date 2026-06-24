# tmux integration for lnav:
#   prefix+L  open the current pane's logs in lnav
#   prefix+M  merge every service window in the session into one lnav timeline
# Lives with the lnav module (not core tmux) so the binds only exist where lnav
# is enabled. programs.tmux.extraConfig merges with the core tmux module.
{pkgs, ...}: let
  # The lnav popups run on a dedicated tmux server (socket -L lnav) so their
  # sessions never clutter the main server's session list / continuum saves.
  # Default prefix (C-b) is kept so C-b d hides the popup; the rest is a clean
  # bar-less UI, detach-on-destroy so quitting lnav closes the popup, and RGB so
  # lnav's per-file palette stays wide.
  lnavServerConf = pkgs.writeText "lnav-tmux.conf" ''
    set -g status off
    set -g detach-on-destroy on
    set -g escape-time 0
    set -g default-terminal "tmux-256color"
    set -ag terminal-features ",*:RGB"
  '';

  # Strip ANSI escapes from stdin and append to $1. pipe-pane emits raw pane
  # bytes (with color codes), which confuse lnav's parsers; capture-pane -p
  # does not, so this keeps the live stream consistent with the seeded history.
  ansiStrip = pkgs.writeShellScript "ansi-strip-append" ''
    exec ${pkgs.gnused}/bin/sed -u 's/\x1b\[[0-9;?]*[a-zA-Z]//g' >>"$1"
  '';

  # $1 = pane id, $2 = log file. -pJS - seeds the whole scrollback (joined,
  # plain). Piping straight through the trailing-blank trim (drops capture-pane's
  # bottom padding) does it in one pass, vs. a second sed -i over the whole file.
  # Targets the main server (no -L): the source panes live there.
  seedAndTail = pkgs.writeShellScript "tmux-lnav-seed" ''
    ${pkgs.tmux}/bin/tmux capture-pane -pJS - -t "$1" \
      | ${pkgs.gnused}/bin/sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >"$2"
    ${pkgs.tmux}/bin/tmux pipe-pane -O -t "$1" "${ansiStrip} '$2'"
  '';

  # $1 = pane id, $2 = log file. Not exec'd, so the trap fires when lnav quits.
  # pipe-pane targets the main server (no -L) where the source pane lives. The
  # HUP/TERM trap routes kill-session/kill-server through the same cleanup
  # (an untrapped SIGHUP would skip the EXIT trap and orphan the pipe + file).
  lnavSession = pkgs.writeShellScript "tmux-lnav-session" ''
    trap '${pkgs.tmux}/bin/tmux pipe-pane -t "$1" 2>/dev/null; ${pkgs.coreutils}/bin/rm -f "$2"' EXIT
    trap 'exit' HUP TERM
    lnav "$2"
  '';

  # $1 = temp dir holding one <id>/<name> file per captured pane, plus a .panes
  # id list. Trap stops each main-server pipe and drops the dir; HUP/TERM route
  # kill-session/kill-server through it too.
  lnavMergeSession = pkgs.writeShellScript "tmux-lnav-merge-session" ''
    trap 'while read -r p; do ${pkgs.tmux}/bin/tmux pipe-pane -t "$p" 2>/dev/null; done <"$1/.panes"; ${pkgs.coreutils}/bin/rm -rf "$1"' EXIT
    trap 'exit' HUP TERM
    lnav "$1"/*/*
  '';

  # lnav lives in a detached per-pane session on the -L lnav server so the popup
  # can be hidden (prefix+d) without losing filters; reopening re-attaches. The
  # pane id is self-queried, not passed in: display-popup does not expand #{...}
  # in its command, but display-message inside the popup sees the active pane.
  paneLnav = pkgs.writeShellScript "tmux-pane-lnav" ''
    tmux=${pkgs.tmux}/bin/tmux
    lt="$tmux -L lnav -f ${lnavServerConf}"
    pane=$($tmux display-message -p '#{pane_id}')
    sess="lnav-$(printf '%s' "$pane" | ${pkgs.coreutils}/bin/tr -cd '0-9')"
    if ! $lt has-session -t "=$sess" 2>/dev/null; then
      log=$(${pkgs.coreutils}/bin/mktemp --suffix=.log)
      ${seedAndTail} "$pane" "$log"
      $lt new-session -d -s "$sess" "${lnavSession} '$pane' '$log'"
    fi
    # env -u TMUX: tmux refuses to attach while $TMUX is set; unset it.
    exec ${pkgs.coreutils}/bin/env -u TMUX $lt new-session -A -s "$sess"
  '';

  # Captures every service pane across the whole session (each service is its own
  # window) and opens them merged in lnav: one timestamp-ordered view, labeled
  # per window. The exclude list skips shells/editors/pagers/vcs/the AI pane; a
  # pane idling at a prompt reports its shell, so it's skipped too. The session
  # is self-queried (display-popup doesn't expand #{...} in its command).
  paneLnavMerge = pkgs.writeShellScript "tmux-pane-lnav-merge" ''
    tmux=${pkgs.tmux}/bin/tmux
    lt="$tmux -L lnav -f ${lnavServerConf}"
    src=$($tmux display-message -p '#{session_id}')
    sess="lnavmrg-$(printf '%s' "$src" | ${pkgs.coreutils}/bin/tr -cd '0-9')"
    if ! $lt has-session -t "=$sess" 2>/dev/null; then
      dir=$(${pkgs.coreutils}/bin/mktemp -d)
      # Pass 1: collect service panes and count how many land in each window.
      # window_name is the label (falls back to the command); read last so spaces
      # land in one field. Service detection keys off the command.
      declare -A wcount=()
      pids=() idxs=() wids=() bases=()
      while read -r pid wid pidx pcmd wname; do
        case "$pcmd" in
          zsh|bash|sh|dash|fish|nu|nvim|vim|vi|nano|emacs|helix|hx|less|more|man|lnav|tmux|htop|btop|top|lazygit|gitui|git|fzf|sesh|ssh|claude|cat|tail|watch) continue ;;
        esac
        base="$wname"; [ -n "$base" ] || base="$pcmd"
        pids+=("$pid"); idxs+=("$pidx"); wids+=("$wid"); bases+=("$base")
        wcount[$wid]=$(( ''${wcount[$wid]:-0} + 1 ))
      done < <($tmux list-panes -s -t "$src" -F '#{pane_id} #{window_id} #{pane_index} #{pane_current_command} #{window_name}')
      n=''${#pids[@]}
      if [ "$n" -eq 0 ]; then
        ${pkgs.coreutils}/bin/rm -rf "$dir"
        $tmux display-message "lnav: no service panes in this session"
        exit 0
      fi
      # Pass 2: seed + live-tail each into its own <pane-id>/<label> file. The
      # index suffix is added only when a window has >1 captured log (so a window
      # split with a non-service pane still labels cleanly); the pane-id subdir
      # backstops genuine label collisions across windows.
      i=0
      while [ "$i" -lt "$n" ]; do
        pid=''${pids[$i]} pidx=''${idxs[$i]} wid=''${wids[$i]} name=''${bases[$i]}
        [ "''${wcount[$wid]}" -gt 1 ] && name="$name.$pidx"
        safe=$(printf '%s' "$name" | ${pkgs.coreutils}/bin/tr -cd 'A-Za-z0-9._-')
        id=$(printf '%s' "$pid" | ${pkgs.coreutils}/bin/tr -cd '0-9')
        [ -n "$safe" ] || safe="$id"
        ${pkgs.coreutils}/bin/mkdir -p "$dir/$id"
        ${seedAndTail} "$pid" "$dir/$id/$safe" &
        printf '%s\n' "$pid" >>"$dir/.panes"
        i=$((i + 1))
      done
      wait
      $lt new-session -d -s "$sess" "${lnavMergeSession} '$dir'"
    fi
    exec ${pkgs.coreutils}/bin/env -u TMUX $lt new-session -A -s "$sess"
  '';
in {
  # prefix+d hides the popup (lnav keeps running); q / Ctrl-C quits and cleans up.
  programs.tmux.extraConfig = ''
    bind L display-popup -E -w 95% -h 95% "${paneLnav}"
    bind M display-popup -E -w 95% -h 95% "${paneLnavMerge}"
  '';
}
