{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.oledCare.idleDpms;

  no-sleep-bin = pkgs.writeShellApplication {
    name = "no-sleep";
    runtimeInputs = with pkgs; [systemd coreutils];
    text = builtins.readFile ./no-sleep.sh;
  };

  no-sleep-completion-zsh = pkgs.writeTextFile {
    name = "no-sleep-zsh-completion";
    destination = "/share/zsh/site-functions/_no-sleep";
    text = ''
      #compdef no-sleep

      _no-sleep() {
        local -a subcmds durations reasons opts
        subcmds=(
          'status:List current sleep/idle inhibitors'
        )
        durations=(
          '30s:30 seconds'
          '1m:1 minute'
          '5m:5 minutes'
          '10m:10 minutes'
          '15m:15 minutes'
          '30m:30 minutes'
          '45m:45 minutes'
          '1h:1 hour'
          '2h:2 hours'
          '4h:4 hours'
          '6h:6 hours'
          '8h:8 hours'
          '12h:12 hours'
          '1d:1 day'
        )
        reasons=(
          'build:long build'
          'compile:compilation in progress'
          'download:large download'
          'upload:large upload'
          'render:rendering'
          'recording:screen recording'
          'presentation:presentation mode'
          'meeting:in a meeting'
          'reading:reading'
          'training:model training'
          'sync:sync in progress'
          'backup:backup running'
        )
        opts=(
          '--why:Reason recorded in systemd-inhibit'
          '--help:Show usage'
          '-h:Show usage'
          '--:End option parsing; rest is command to run'
        )

        # `status` is a terminal subcommand — nothing follows it.
        if [[ "$words[2]" == status ]]; then
          return
        fi

        # Find `--` separator. After it, complete arbitrary commands.
        local i sep=0
        for (( i = 2; i < CURRENT; i++ )); do
          if [[ "$words[i]" == "--" ]]; then
            sep=$i
            break
          fi
        done

        if (( sep > 0 )); then
          if (( CURRENT == sep + 1 )); then
            _command_names -e
          else
            _normal
          fi
          return
        fi

        # `--why=<value>` completion.
        if [[ "$words[CURRENT]" == --why=* ]]; then
          compset -P '--why='
          _describe -V 'reason' reasons
          return
        fi

        # After `--why`, suggest a reason.
        if [[ "$words[CURRENT-1]" == --why ]]; then
          _describe -V 'reason' reasons
          return
        fi

        # Has a positional (duration) already been consumed?
        local positional_seen=0
        for (( i = 2; i < CURRENT; i++ )); do
          case "$words[i]" in
            --why) (( i++ )) ;;
            --why=*) ;;
            -h|--help) return ;;
            --) ;;
            *) positional_seen=1 ;;
          esac
        done

        if (( positional_seen )); then
          # Script ignores any args after the duration (unless first was `--`).
          _message 'no more arguments (use `--` before duration to run a command)'
          return
        fi

        # Direct sequential _describe calls — each adds candidates to the same
        # completion menu. `_alternative` had eval/quoting issues with our
        # action strings, so we avoid it.
        _describe -V 'subcommand' subcmds
        _describe -V 'duration' durations
        _describe -V 'option' opts
      }

      _no-sleep "$@"
    '';
  };

  no-sleep-completion-bash = pkgs.writeTextFile {
    name = "no-sleep-bash-completion";
    destination = "/share/bash-completion/completions/no-sleep";
    text = ''
      _no_sleep_complete() {
        local cur="''${COMP_WORDS[COMP_CWORD]}"
        local prev="''${COMP_WORDS[COMP_CWORD-1]}"
        local durations="30s 1m 5m 10m 15m 30m 45m 1h 2h 4h 6h 8h 12h 1d"
        local reasons="build compile download upload render recording presentation meeting reading training sync backup"

        # `status` is terminal — nothing follows it.
        if [ "''${COMP_WORDS[1]:-}" = "status" ] && [ "$COMP_CWORD" -gt 1 ]; then
          return 0
        fi

        # Locate `--` separator. After it, complete commands then file args.
        local i sep=-1
        for (( i = 1; i < COMP_CWORD; i++ )); do
          if [ "''${COMP_WORDS[i]}" = "--" ]; then
            sep=$i
            break
          fi
        done

        if [ "$sep" -ge 0 ]; then
          if [ "$COMP_CWORD" -eq $((sep + 1)) ]; then
            mapfile -t COMPREPLY < <(compgen -c -- "$cur")
          else
            mapfile -t COMPREPLY < <(compgen -f -- "$cur")
          fi
          return 0
        fi

        # `--why=<value>` completion.
        if [[ "$cur" == --why=* ]]; then
          local val="''${cur#--why=}"
          local matches
          mapfile -t matches < <(compgen -W "$reasons" -- "$val")
          COMPREPLY=()
          local k
          for k in "''${!matches[@]}"; do
            COMPREPLY+=("--why=''${matches[k]}")
          done
          return 0
        fi

        # After `--why`, suggest a reason.
        if [ "$prev" = "--why" ]; then
          mapfile -t COMPREPLY < <(compgen -W "$reasons" -- "$cur")
          return 0
        fi

        # Has a non-flag positional already been provided?
        local positional_seen=0
        for (( i = 1; i < COMP_CWORD; i++ )); do
          case "''${COMP_WORDS[i]}" in
            --why) i=$((i + 1)) ;;
            --why=*) ;;
            -h|--help) return 0 ;;
            --) ;;
            *) positional_seen=1 ;;
          esac
        done

        if [ "$positional_seen" -eq 1 ]; then
          # Script ignores trailing args once a duration is parsed.
          COMPREPLY=()
          return 0
        fi

        local opts="status --why --help -h -- $durations"
        mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
      }
      complete -F _no_sleep_complete no-sleep
    '';
  };

  no-sleep = pkgs.symlinkJoin {
    name = "no-sleep";
    paths = [no-sleep-bin no-sleep-completion-zsh no-sleep-completion-bash];
  };
in {
  config = lib.mkIf cfg.enable {
    home.packages = [no-sleep];

    services.hypridle.settings.listener = [
      {
        timeout = 180;
        on-timeout = "loginctl lock-session";
      }
      {
        timeout = 240;
        on-timeout = "hyprctl dispatch dpms off";
        on-resume = "hyprctl dispatch dpms on";
      }
    ];
  };
}
