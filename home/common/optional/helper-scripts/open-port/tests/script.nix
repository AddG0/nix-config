# Runs open-port against a fake firewall, sudo and systemd, and checks its zsh completion; cases in the .bats files.
{
  harness,
  pkgs,
  ...
}: let
  # One nixos-fw chain per binary, a rule per line in $IPTABLES_STATE.<binary>; $NO_NIXOS_FW removes the chain.
  iptablesScript = pkgs.writeShellScript "fake-iptables" ''
    state="$IPTABLES_STATE.$(basename "$0")"
    touch "$state"
    [ "$1" != -w ] || shift 2
    op=$1
    shift 2
    [ -z "''${NO_NIXOS_FW:-}" ] || exit 1
    case "$op" in
      -L) exit 0 ;;
      -C) grep -Fxq -- "$*" "$state" ;;
      -I) shift && echo "$*" >>"$state" ;;
      -D)
        line=$(grep -Fxn -- "$*" "$state" | head -1 | cut -d: -f1)
        [ -n "$line" ] || exit 1
        sed -i "''${line}d" "$state"
        ;;
    esac
  '';
  fakeIptables = pkgs.runCommand "fake-iptables" {} ''
    mkdir -p $out/bin
    ln -s ${iptablesScript} $out/bin/iptables
    ln -s ${iptablesScript} $out/bin/ip6tables
  '';

  # sudo running its command as is, logging it to $SUDO_LOG.
  sudoScript = pkgs.writeShellScript "fake-sudo" ''
    echo "$*" >>"$SUDO_LOG"
    exec "$@"
  '';
  # Close timers, one unit per line in $SYSTEMD_STATE; patterns glob like systemctl's fnmatch(FNM_NOESCAPE).
  systemctlScript = pkgs.writeShellScript "fake-systemctl" ''
    touch "$SYSTEMD_STATE"
    command=$1
    shift
    case "$command" in
      list-units | list-timers)
        for pattern in "$@"; do
          case "$pattern" in -*) continue ;; esac
          while IFS= read -r unit; do
            [[ $unit == ''${pattern//\\/\\\\} ]] && echo "$unit"
          done <"$SYSTEMD_STATE"
        done
        ;;
      stop)
        for unit in "$@"; do
          grep -vFx -- "$unit" "$SYSTEMD_STATE" >"$SYSTEMD_STATE.next" || true
          mv "$SYSTEMD_STATE.next" "$SYSTEMD_STATE"
        done
        ;;
    esac
    exit 0
  '';
  # Arms a timer by adding it to $SYSTEMD_STATE, saving its delay and command as $SYSTEMD_STATE.<unit>.after/.command.
  systemdRunScript = pkgs.writeShellScript "fake-systemd-run" ''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --unit=*) unit=''${1#--unit=} ;;
        --on-active=*) after=''${1#--on-active=} ;;
        --*) ;;
        *) break ;;
      esac
      shift
    done
    echo "$unit.timer" >>"$SYSTEMD_STATE"
    printf '%s' "$after" >"$SYSTEMD_STATE.$unit.after"
    printf '%s' "$3" >"$SYSTEMD_STATE.$unit.command"
  '';
  fakeSudoAndSystemd = pkgs.runCommand "fake-sudo-and-systemd" {} ''
    mkdir -p $out/bin
    ln -s ${sudoScript} $out/bin/sudo
    ln -s ${systemctlScript} $out/bin/systemctl
    ln -s ${systemdRunScript} $out/bin/systemd-run
    ln -s ${pkgs.systemd}/bin/systemd-escape $out/bin/
  '';

  openPort = pkgs.callPackage ../package.nix {iptables = fakeIptables;};
in
  harness.bats "open-port" [./open-port.bats ./completion.bats] {
    nativeBuildInputs = [fakeSudoAndSystemd pkgs.zsh];
    openPort = "${openPort}/bin/open-port";
    openPortShare = "${openPort}/share";
    captureCompletion = "${./_capture-completion.zsh}";
  }
