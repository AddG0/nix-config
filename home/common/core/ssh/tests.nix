# Three suites over the REAL tmux-ssh-auth-sock-link script: logic against a
# stub tmux, behaviour against a live one, and the zsh ordering it relies on.
#
# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (pkgs) runCommand writeShellScriptBin coreutils python3;
  inherit (pkgs) tmux util-linux gnugrep ncurses;

  script = pkgs.callPackage ./agent-link.nix {};
  # Stand-in for tmux:
  #   list-clients     -> $CLIENTS, lines of "<activity> <client-name>"
  #   show-environment -> SSH_AUTH_SOCK=$SESSION_SOCK, omitted when unset
  stub = writeShellScriptBin "tmux-stub" ''
    case "$1" in
      list-clients)
        # -F '#{client_name}' asks for names only; anything else wants both.
        if [ "$*" = "list-clients -F #{client_name}" ]; then
          cut -d' ' -f2- "$CLIENTS" 2>/dev/null || true
        else
          cat "$CLIENTS" 2>/dev/null || true
        fi
        ;;
      show-environment)
        if [ -n "''${SESSION_SOCK:-}" ]; then echo "SSH_AUTH_SOCK=$SESSION_SOCK"; fi
        ;;
      set-environment)
        shift
        echo "$*" >>"$SETENV_LOG"
        ;;
    esac
  '';
  # The stub tests above pin the logic; this one pins tmux's actual behaviour,
  # where the undocumented format semantics could change under us.
  integration =
    runCommand "tmux-ssh-auth-sock-link-integration" {
      nativeBuildInputs = [coreutils tmux util-linux gnugrep ncurses python3];
    } ''
          export HOME=$PWD/home TERM=xterm-256color
          mkdir -p "$HOME/.ssh"
          link=$HOME/.ssh/ssh_auth_sock
          tm="tmux -L itest"

          mksock() { ${python3}/bin/python3 -c "
      import socket,sys
      s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1)
      " "$1"; }
          fail() { echo "FAIL: $1"; $tm kill-server 2>/dev/null || true; exit 1; }
          link_is() { [ "$(readlink "$link" 2>/dev/null)" = "$1" ]; }
          # Hooks run backgrounded, so poll rather than guess a sleep.
          wait_link() {
            local n=0
            while [ $n -lt 100 ]; do
              link_is "$1" && return 0
              sleep 0.1
              n=$((n + 1))
            done
            return 1
          }
          # script(1) only hands its child a pty when its own stdin is not /dev/null.
          attach() { script -q -c "$tm attach -t t" /dev/null <"$1" >/dev/null 2>&1 & }

          mksock "$PWD/agentA"
          mksock "$PWD/agentB"
          mkfifo fifoA fifoB

          $tm new-session -d -s t -x 80 -y 24
          $tm source-file ${pkgs.writeText "hooks.conf" (import ./hooks.nix "${script}/bin/tmux-ssh-auth-sock-link")}

          echo "--- [real tmux] the link follows the client that attached"
          SSH_AUTH_SOCK=$PWD/agentA attach fifoA
          exec 3>fifoA
          wait_link "$PWD/agentA" || fail "link did not follow the attaching client"

          echo "--- [real tmux] a pane that never runs a shell rc still gets the link"
          $tm new-window -t t -d "sh -c 'printenv SSH_AUTH_SOCK > $PWD/paneenv'"
          for _ in $(seq 30); do [ -s "$PWD/paneenv" ] && break; sleep 0.1; done
          grep -qx "$link" "$PWD/paneenv" || fail "non-shell pane did not inherit the link"

          echo "--- [real tmux] a second client takes the link"
          SSH_AUTH_SOCK=$PWD/agentB attach fifoB
          exec 4>fifoB
          wait_link "$PWD/agentB" || fail "link did not follow the second client"

          echo "--- [real tmux] typing at the first client moves the link back"
          printf ' ' >&3
          wait_link "$PWD/agentA" || fail "client-active did not follow the real switch"

          exec 3>&- 4>&-
          $tm kill-server 2>/dev/null || true
          echo "integration ok"
          touch $out
    '';
  # Found rather than named, so retiring a host cannot quietly leave this
  # pointing at nothing.
  pluginHost = let
    enabled = name: let
      cfg = self.nixosConfigurations.${name}.config;
    in
      cfg.home-manager.users.${cfg.hostSpec.primaryUsername}.programs.ssh.enableTraditionalAgent or false;
  in
    lib.findFirst enabled null (lib.naturalSort (builtins.attrNames self.nixosConfigurations));

  pluginHostZshrc = let
    cfg = self.nixosConfigurations.${pluginHost}.config;
  in
    cfg.home-manager.users.${cfg.hostSpec.primaryUsername}.programs.zsh.initContent;

  # Reorder the zsh halves around oh-my-zsh and a host with its own key silently
  # stops loading it — invisible to any test of the script itself.
  ordering =
    lib.throwIf (pluginHost == null)
    "ssh/tests.nix: no host enables the ssh-agent plugin, so this guard is vacuous"
    runCommand "ssh-agent-zsh-order" {
      zshrc = pkgs.writeText "zshrc" pluginHostZshrc;
    } ''
      line() {
        grep -n "$1" "$zshrc" | head -1 | cut -d: -f1
      }
      clear=$(line 'unset SSH_AUTH_SOCK')
      omz=$(line 'source \$ZSH/oh-my-zsh.sh')
      claim=$(line 'export SSH_AUTH_SOCK="\$HOME/.ssh/ssh_auth_sock"')

      for v in clear omz claim; do
        [ -n "''${!v}" ] || {
          echo "FAIL: could not locate the $v line in the rendered zshrc"
          exit 1
        }
      done
      [ "$clear" -lt "$omz" ] || {
        echo "FAIL: dead-socket clear ($clear) must precede oh-my-zsh ($omz)"
        exit 1
      }
      [ "$claim" -gt "$omz" ] || {
        echo "FAIL: link claim ($claim) must follow oh-my-zsh ($omz)"
        exit 1
      }
      echo "zsh ordering ok on ${pluginHost}: clear=$clear omz=$omz claim=$claim"
      touch $out
    '';
in
  runCommand "tmux-ssh-auth-sock-link-tests" {
    nativeBuildInputs = [coreutils];
    inherit integration ordering;
  } ''
        export TMUX_SSH_LINK_TMUX=${stub}/bin/tmux-stub
        run=${script}/bin/tmux-ssh-auth-sock-link

        fail() { echo "FAIL: $1"; exit 1; }

        setup() {
          rm -rf work; mkdir -p work/map
          export SSH_AUTH_SOCK_LINK=$PWD/work/link
          export SSH_AUTH_SOCK_MAP=$PWD/work/map
          export CLIENTS=$PWD/work/clients
          export SETENV_LOG=$PWD/work/setenv
          : >"$CLIENTS"
          : >"$SETENV_LOG"
          unset SESSION_SOCK
        }
        # A real AF_UNIX socket, since the script gates on -S.
        mksock() { ${python3}/bin/python3 -c "
    import socket,sys
    s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1)
    " "$1"; }
        target() { readlink "$SSH_AUTH_SOCK_LINK" 2>/dev/null || echo NONE; }

        echo "--- attach records the client's agent and aims the link at it"
        setup; mksock work/agentA
        export SESSION_SOCK=$PWD/work/agentA
        $run attach /dev/pts/1
        [ "$(target)" = "$PWD/work/agentA" ] || fail "attach did not aim at the client's agent"
        [ "$(readlink "$SSH_AUTH_SOCK_MAP/dev+pts+1")" = "$PWD/work/agentA" ] || fail "attach did not record the map entry"

        echo "--- the link follows the most recently active client, not the newest attach"
        setup; mksock work/agentA; mksock work/agentB
        ln -sfn "$PWD/work/agentA" "$SSH_AUTH_SOCK_MAP/dev+pts+1"
        ln -sfn "$PWD/work/agentB" "$SSH_AUTH_SOCK_MAP/dev+pts+2"
        printf '100 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
        $run active
        [ "$(target)" = "$PWD/work/agentB" ] || fail "did not pick the highest-activity client"
        printf '300 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
        $run active
        [ "$(target)" = "$PWD/work/agentA" ] || fail "did not follow the switch back"

        echo "--- a client with a dead agent is skipped in favour of a live one"
        setup; mksock work/agentA
        ln -sfn "$PWD/work/gone" "$SSH_AUTH_SOCK_MAP/dev+pts+2"
        ln -sfn "$PWD/work/agentA" "$SSH_AUTH_SOCK_MAP/dev+pts+1"
        printf '100 /dev/pts/1\n999 /dev/pts/2\n' >"$CLIENTS"
        $run active
        [ "$(target)" = "$PWD/work/agentA" ] || fail "did not skip the client with a dead agent"

        echo "--- detach with a survivor hands the link to the client still attached"
        setup; mksock work/agentA; mksock work/agentB
        ln -sfn "$PWD/work/agentA" "$SSH_AUTH_SOCK_MAP/dev+pts+1"
        ln -sfn "$PWD/work/agentB" "$SSH_AUTH_SOCK_MAP/dev+pts+2"
        ln -sfn "$PWD/work/agentB" "$SSH_AUTH_SOCK_LINK"
        printf '100 /dev/pts/1\n' >"$CLIENTS"
        $run detach
        [ "$(target)" = "$PWD/work/agentA" ] || fail "detach did not follow the surviving client"

        echo "--- with nobody attached the link is left dead, so callers fail fast"
        setup
        ln -sfn "$PWD/work/gone" "$SSH_AUTH_SOCK_LINK"
        : >"$CLIENTS"
        $run detach
        [ "$(target)" = "$PWD/work/gone" ] || fail "detach re-aimed the link with no client attached"
        [ ! -S "$SSH_AUTH_SOCK_LINK" ] || fail "link should not resolve once nobody is attached"

        echo "--- new panes are handed the link, not the raw per-connection socket"
        setup; mksock work/agentA
        export SESSION_SOCK=$PWD/work/agentA
        $run attach /dev/pts/1
        grep -qx "SSH_AUTH_SOCK $SSH_AUTH_SOCK_LINK" "$SETENV_LOG" || fail "session env was not pointed at the link"
        grep -qx -- "-g SSH_AUTH_SOCK $SSH_AUTH_SOCK_LINK" "$SETENV_LOG" || fail "global env was not pointed at the link"

        echo "--- a client that brought no agent does not overwrite the map with the link"
        setup; mksock work/agentA
        ln -sfn "$PWD/work/agentA" "$SSH_AUTH_SOCK_LINK"
        export SESSION_SOCK=$SSH_AUTH_SOCK_LINK
        $run attach /dev/pts/3
        [ ! -e "$SSH_AUTH_SOCK_MAP/dev+pts+3" ] || fail "recorded the link as a client's own agent"

        echo "--- an entry for a client that is no longer attached is retired"
        setup; mksock work/agentA; mksock work/agentB
        ln -sfn "$PWD/work/agentB" "$SSH_AUTH_SOCK_MAP/dev+pts+8"
        ln -sfn "$PWD/work/agentB" "$SSH_AUTH_SOCK_MAP/dev+pts+2"
        printf '100 /dev/pts/1\n200 /dev/pts/2\n' >"$CLIENTS"
        export SESSION_SOCK=$PWD/work/agentA
        $run attach /dev/pts/1
        [ ! -e "$SSH_AUTH_SOCK_MAP/dev+pts+8" ] || fail "kept an entry whose client had left"
        [ -e "$SSH_AUTH_SOCK_MAP/dev+pts+1" ] || fail "gc removed the attaching client's entry"
        [ -e "$SSH_AUTH_SOCK_MAP/dev+pts+2" ] || fail "gc removed a second still-connected client's entry"

        echo "--- a map entry whose agent died is garbage collected"
        setup; mksock work/agentA
        ln -sfn "$PWD/work/gone" "$SSH_AUTH_SOCK_MAP/dev+pts+9"
        export SESSION_SOCK=$PWD/work/agentA
        $run attach /dev/pts/1
        [ ! -e "$SSH_AUTH_SOCK_MAP/dev+pts+9" ] || fail "stale map entry was not collected"

        echo "--- a client name that is not a device path is refused"
        setup; mksock work/agentA
        export SESSION_SOCK=$PWD/work/agentA
        $run attach "../escape"
        [ ! -e "$SSH_AUTH_SOCK_MAP/../escape" ] || fail "accepted a client name outside the map"

        echo "stub tests passed; integration: $integration; ordering: $ordering"
        touch $out
  ''
