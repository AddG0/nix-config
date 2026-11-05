# Aims ~/.ssh/ssh_auth_sock at the agent of the most recently active tmux client (ADR 0023).
{
  writeShellApplication,
  coreutils,
  flock,
  gnused,
  gnugrep,
  libnotify,
  openssh,
  tmux,
}:
writeShellApplication {
  name = "tmux-ssh-auth-sock-link";
  runtimeInputs = [coreutils flock gnused gnugrep libnotify openssh tmux];
  text = ''
    # Overridable so tests can drive the script with a stub tmux.
    tmux_bin="''${TMUX_SSH_LINK_TMUX:-tmux}"
    if [ -z "''${HOME:-}" ]; then
      printf 'tmux-ssh-auth-sock-link: HOME is unset\n' >&2
      exit 1
    fi
    link="''${SSH_AUTH_SOCK_LINK:-$HOME/.ssh/ssh_auth_sock}"
    map="''${SSH_AUTH_SOCK_MAP:-$HOME/.ssh/agent-by-client}"
    probe_timeout="''${SSH_AUTH_SOCK_PROBE_TIMEOUT:-2}"
    lock_wait="''${SSH_AUTH_SOCK_LOCK_WAIT:-10}"
    notify_timeout="''${SSH_AUTH_SOCK_NOTIFY_TIMEOUT:-5}"
    # Never created: the link aims here to refuse, and clients without an agent record it.
    no_agent="$map/.no-agent"

    # run-shell -b discards stderr, so every report also goes to the journal and the screen.
    warn() {
      printf 'tmux-ssh-auth-sock-link: %s\n' "$1" >&2
      if command -v logger >/dev/null; then
        logger -t tmux-ssh-auth-sock-link -- "$1" || printf 'tmux-ssh-auth-sock-link: logger failed\n' >&2
      fi
      # No client to show it on is normal from the detach hook.
      "$tmux_bin" display-message "ssh-auth-sock: $1" 2>/dev/null || true
      if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        timeout "$notify_timeout" notify-send --app-name=ssh-agent "SSH agent" "$1" ||
          printf 'tmux-ssh-auth-sock-link: notify-send failed\n' >&2
      fi
    }

    if ! mkdir -p "$map"; then
      warn "cannot create $map"
      exit 1
    fi

    # Hooks fire together on attach and detach; interleaved runs could aim at an older client.
    exec 9>"$map/.lock"
    if ! flock -w "$lock_wait" 9; then
      warn "another run held $map/.lock for ''${lock_wait}s"
      exit 1
    fi

    # ln -sfn unlinks then creates, leaving a moment with no link at all.
    relink() {
      local tmp="$2.tmp.$$"
      if ! ln -sfn "$1" "$tmp" || ! mv -Tf "$tmp" "$2"; then
        rm -f "$tmp"
        return 1
      fi
    }

    # /dev/pts/4 -> dev+pts+4. Refused rather than escaped, so an unexpected
    # client name cannot name a file outside the map.
    keyfor() {
      case "$1" in
        /dev/*) ;;
        *) return 1 ;;
      esac
      case "$1" in
        *+* | *" "*) return 1 ;;
      esac
      printf '%s' "''${1#/}" | tr '/' '+'
    }

    # A forwarded socket from a sleeping laptop still accepts, then never answers.
    answers() {
      local rc=0
      SSH_AUTH_SOCK="$1" timeout "$probe_timeout" ssh-add -l >/dev/null 2>&1 || rc=$?
      # 1 is "no identities": the agent answered.
      [ "$rc" -le 1 ]
    }

    # -S and -O follow the symlink, so a stale target can only ever fail closed.
    usable() {
      if [ -z "$1" ] || [ ! -S "$1" ] || [ ! -O "$1" ]; then
        return 1
      fi
      answers "$1"
    }

    # 1: the agent is unusable. 2: the link could not be written, already reported.
    aim() {
      if ! usable "$1"; then
        return 1
      fi
      if [ "$1" != "$link" ] && [ "$(readlink "$link" 2>/dev/null)" != "$1" ] &&
        ! relink "$1" "$link"; then
        warn "cannot update $link"
        return 2
      fi
      return 0
    }

    # Falling through to an older candidate would sign with keys the most recent caller did not mean.
    refuse() {
      if [ "$(readlink "$link" 2>/dev/null)" = "$no_agent" ]; then
        return 0
      fi
      if ! relink "$no_agent" "$link"; then
        warn "cannot update $link, which may still reach an agent it should not"
        return 1
      fi
      warn "$1 is the most recent client but has no usable agent; signing is refused until it detaches or another client is active"
    }

    # aim, refusing only when the agent is at fault.
    aim_or_refuse() {
      local rc=0
      aim "$1" || rc=$?
      if [ "$rc" -eq 1 ]; then
        refuse "$2"
      fi
      [ "$rc" -eq 0 ]
    }

    # No server means no clients; any other failure is reported and returns 1, so callers keep their state.
    clients() {
      local out
      if ! out=$("$tmux_bin" list-clients -F "$1" 2>&1); then
        case "$out" in
          *"no server running"*) return 0 ;;
          *)
            warn "cannot list tmux clients, leaving the link and its records as they are: $out"
            return 1
            ;;
        esac
      fi
      if [ -n "$out" ]; then printf '%s\n' "$out"; fi
    }

    gc() {
      local names connected l n
      names=$(clients '#{client_name}') || return 1
      connected=$(printf '%s\n' "$names" | while read -r n; do
        if k=$(keyfor "$n"); then printf '%s\n' "$k"; fi
      done)
      for l in "$map"/*; do
        [ -L "$l" ] || continue
        case "$(basename "$l")" in
          *.tmp.*) continue ;;
        esac
        # Retired only when its client leaves, so a dead agent keeps blocking fallback.
        if ! printf '%s\n' "$connected" | grep -qxF "$(basename "$l")"; then
          rm -f "$l"
        fi
      done
    }

    # #{hook_client} names the client that just *lost* focus and #{client_active}
    # is empty in tmux 3.7, so activity order is the only usable "who is here".
    aim_active() {
      local name key target ranked
      ranked=$(clients '#{client_activity} #{client_name}') || return 1
      while read -r name; do
        key=$(keyfor "$name") || continue
        # A client the hooks never recorded is no evidence either way.
        target=$(readlink "$map/$key" 2>/dev/null) || continue
        aim_or_refuse "$target" "$name"
        return
      done < <(printf '%s\n' "$ranked" | sort -k1,1rn -k2,2 | cut -d' ' -f2-)
      return 1
    }

    case "''${1:-}" in
      attach)
        # One read for both variables: a missing variable and a failed read look the same per name.
        if ! session_env=$("$tmux_bin" show-environment 2>&1); then
          warn "cannot read the session environment, so the attaching client is not recorded: $session_env"
          session_env=""
          readable=0
        else
          readable=1
        fi
        sock=$(printf '%s\n' "$session_env" | sed -n 's/^SSH_AUTH_SOCK=//p')
        # A client inheriting the stable link has no new agent to record.
        if [ "$sock" = "$link" ]; then
          sock=""
          inherited_link=1
        else
          inherited_link=0
        fi
        target=""
        if [ "$readable" -eq 1 ]; then
          if [ -n "$sock" ]; then
            target=$sock
          elif [ "$inherited_link" -eq 0 ]; then
            target=$no_agent
          fi
        fi
        gc || exit 1
        if key=$(keyfor "''${2:-}") && [ -n "$target" ]; then
          relink "$target" "$map/$key" || warn "cannot record $map/$key"
        fi
        if [ -n "$target" ]; then
          aim_or_refuse "$target" "''${2:-attached client}" || true
        else
          aim_active || true
        fi
        # Panes inherit the session env at creation and only interactive zsh
        # rewrites it, so `new-window <cmd>` would bake in a socket that dies
        # with this connection. update-environment re-seeds raw on next attach.
        "$tmux_bin" set-environment -g SSH_AUTH_SOCK "$link" ||
          warn "could not set SSH_AUTH_SOCK globally"
        "$tmux_bin" set-environment SSH_AUTH_SOCK "$link" ||
          warn "could not set SSH_AUTH_SOCK for this session"
        ;;
      active)
        aim_active || true
        ;;
      # #{client_name} is empty here; with nobody left the link stays dead.
      detach)
        gc || exit 1
        aim_active || true
        ;;
      *)
        printf 'usage: tmux-ssh-auth-sock-link attach <client>|active|detach\n' >&2
        exit 2
        ;;
    esac
  '';

  meta.description = "Point a stable SSH_AUTH_SOCK symlink at the active tmux client's agent";
}
