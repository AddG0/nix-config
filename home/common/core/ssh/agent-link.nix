# Panes outlive the connection whose agent socket they were handed, so they hold
# a stable symlink that this script re-aims at the active client's agent.
# Driven by the tmux hooks in ./default.nix.
{
  writeShellApplication,
  coreutils,
  gnused,
  gnugrep,
  tmux,
}:
writeShellApplication {
  name = "tmux-ssh-auth-sock-link";
  runtimeInputs = [coreutils gnused gnugrep tmux];
  text = ''
    # Overridable so tests can drive the script with a stub tmux.
    tmux_bin="''${TMUX_SSH_LINK_TMUX:-tmux}"
    if [ -z "''${HOME:-}" ]; then
      printf 'tmux-ssh-auth-sock-link: HOME is unset\n' >&2
      exit 1
    fi
    link="''${SSH_AUTH_SOCK_LINK:-$HOME/.ssh/ssh_auth_sock}"
    map="''${SSH_AUTH_SOCK_MAP:-$HOME/.ssh/agent-by-client}"
    # Reporting channel: run-shell -b discards stderr, so a hook that cannot do
    # its job would otherwise fail invisibly.
    warn() {
      printf 'tmux-ssh-auth-sock-link: %s\n' "$1" >&2
      "$tmux_bin" display-message "ssh-auth-sock: $1" 2>/dev/null || true
    }

    if ! mkdir -p "$map"; then
      warn "cannot create $map"
      exit 1
    fi

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

    # -S follows the symlink, so a stale target can only ever fail closed.
    aim() {
      if [ -z "$1" ] || [ ! -S "$1" ]; then
        return 1
      fi
      if [ "$1" != "$link" ] && ! ln -sfn "$1" "$link"; then
        warn "cannot update $link"
        return 1
      fi
      return 0
    }

    gc() {
      local connected l
      # keyfor deliberately emits no trailing newline, so terminate each here.
      connected=$("$tmux_bin" list-clients -F '#{client_name}' 2>/dev/null |
        while read -r n; do
          if k=$(keyfor "$n"); then printf '%s\n' "$k"; fi
        done)
      for l in "$map"/*; do
        [ -L "$l" ] || continue
        # A departed client cannot be named on detach, so absence from
        # list-clients is what retires its entry.
        if [ ! -S "$l" ] || ! printf '%s\n' "$connected" | grep -qxF "$(basename "$l")"; then
          rm -f "$l"
        fi
      done
    }

    # #{hook_client} names the client that just *lost* focus and #{client_active}
    # is empty in tmux 3.7, so activity order is the only usable "who is here".
    aim_active() {
      local name key target
      while read -r name; do
        key=$(keyfor "$name") || continue
        target=$(readlink "$map/$key" 2>/dev/null) || continue
        if aim "$target"; then
          return 0
        fi
      done < <("$tmux_bin" list-clients -F '#{client_activity} #{client_name}' 2>/dev/null |
        sort -k1,1rn -k2,2 | cut -d' ' -f2-)
      return 1
    }

    case "''${1:-}" in
      attach)
        sock=$("$tmux_bin" show-environment SSH_AUTH_SOCK 2>/dev/null |
          sed -n 's/^SSH_AUTH_SOCK=//p') || sock=""
        # A client that brought no agent leaves the link we wrote last time.
        if [ "$sock" = "$link" ]; then
          sock=""
        fi
        gc
        if key=$(keyfor "''${2:-}") && [ -S "$sock" ]; then
          ln -sfn "$sock" "$map/$key" || warn "cannot record $map/$key"
        fi
        # No live agent anywhere is normal (nobody attached), so not a warning.
        aim "$sock" || aim_active || true
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
      # No client argument: #{client_name} is empty in this hook. With nobody
      # left the link stays dead, so callers fail fast rather than reach an
      # agent whose approval prompt no one is there to answer.
      detach)
        gc
        aim_active || true
        ;;
    esac
  '';

  meta.description = "Point a stable SSH_AUTH_SOCK symlink at the active tmux client's agent";
}
