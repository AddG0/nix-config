# Announce process crashes and offer to hand them to a coding agent.
#
# systemd-coredump journals every dump under a fixed MESSAGE_ID with structured
# COREDUMP_* fields, which carry more than the core filenames do. Reading the
# journal rather than watching /var/lib/systemd/coredump also keeps working if
# Storage= ever changes, and sees each entry in a burst instead of coalescing
# them the way a path unit would.
{
  config,
  lib,
  pkgs,
  ...
}: let
  agentCfg = config.programs.code-assistant-profiles;
  inherit (agentCfg) launcher;

  # `launcher` is null while code-assistant-profiles is disabled as well as when
  # no target is enabled, so it covers both on its own.
  hasAgent = launcher != null && agentCfg.defaultAgent != null;

  # Fixed app-id so a windowrule can single out the diagnosis window.
  appId = "dev.crash-capture.diagnosis";

  # The flake nh builds from, so a diagnosis that finds a config fix opens in the
  # tree holding it. $HOME is resolved here because user units get no session vars.
  configDir = lib.replaceStrings ["$HOME"] [config.home.homeDirectory] config.home.sessionVariables.NH_FLAKE;

  # See systemd.journal-fields(7).
  coredumpMessageId = "fc2e22bc6ee647b6b90729ab34a250b1";

  notifier = pkgs.writeShellApplication {
    name = "crash-capture-notify";
    runtimeInputs = [
      launcher
      pkgs.coreutils
      pkgs.ghostty
      pkgs.libnotify
      pkgs.systemd
      pkgs.walker
    ];
    text = ''
      name=''${1:?usage: crash-capture-notify <name> <pid> <exe> <signal>}
      pid=$2
      exe=$3
      signal=$4

      # The shell owns org.freedesktop.Notifications, so a shell crash takes the
      # notification server down with it and a toast sent into that gap is lost.
      # The crash least likely to be delivered is the one most worth reporting.
      for _ in $(seq 60); do
        if busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
             org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications \
             >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done

      # Looked up live so the report carries a timestamp; a rotated-away core
      # only costs that one field.
      when=$(coredumpctl list "$pid" --no-pager --no-legend 2>/dev/null | tail -1 | cut -d' ' -f1-4) || true

      diagnose() {
        prompt="A process crashed on this NixOS machine and I want to know why.

      What systemd-coredump recorded:
        process:  $name
        PID:      $pid
        binary:   $exe
        signal:   $signal
        time:     ''${when:-unknown}"

        # A missing checkout would otherwise make agent-run reject --cwd and turn
        # the click into a no-op.
        cwd=()
        if [[ -d ${configDir} ]]; then
          cwd=(--cwd ${configDir})
        fi

        ghostty --class=${appId} -e \
          agent-run "''${cwd[@]}" "$@" --skill diagnose-crash --prompt "$prompt"
      }

      # -A implies --wait, so this blocks until the toast is answered or expires;
      # the caller runs it detached for that reason. No click prints nothing.
      action=$(notify-send \
        --urgency critical \
        --app-name crash-capture \
        --icon dialog-error \
        --action diagnose="Diagnose with AI" \
        --action pick="Pick agent…" \
        "Process crashed: $name" \
        "$signal — hand it to your coding agent") || true

      case "$action" in
        diagnose)
          diagnose
          ;;
        pick)
          agent=$(agent-run --list-agents | walker --dmenu --placeholder "Diagnose crash with…") || exit 0
          [ -n "$agent" ] && diagnose --agent "$agent"
          ;;
      esac
    '';
  };

  watcher = pkgs.writeShellApplication {
    name = "crash-capture-watch";
    runtimeInputs = [notifier pkgs.jq pkgs.systemd];
    text = ''
      # Crash loops dump core repeatedly, so announce each program at most once
      # a window.
      dedupe=''${CRASH_CAPTURE_DEDUPE_SECONDS:-60}
      # Extended regex of process names never worth announcing.
      ignore=''${CRASH_CAPTURE_IGNORE:-}

      declare -A last_notified

      # -n 0 so a restart does not re-announce crashes already dealt with.
      while IFS= read -r entry; do
        fields=$(jq -r '[(._UID // "-"),
                         (.COREDUMP_COMM // "-"),
                         (.COREDUMP_PID // "-"),
                         (.COREDUMP_EXE // "-"),
                         (.COREDUMP_SIGNAL_NAME // "-")] | @tsv' <<<"$entry" 2>/dev/null) || continue
        IFS=$'\t' read -r uid comm pid exe signal <<<"$fields"

        [[ $pid =~ ^[0-9]+$ ]] || continue

        # Only this user's crashes; a daemon dumping core is a sysadmin's problem.
        [[ $uid =~ ^[0-9]+$ ]] || continue
        if ((uid != UID)); then
          continue
        fi

        # comm is truncated to 15 characters, so prefer the executable's basename.
        name=$comm
        if [[ $exe == /* ]]; then
          name=''${exe##*/}
        fi

        if [[ -n $ignore && $name =~ $ignore ]]; then
          continue
        fi

        # Never announce our own machinery, or it notifies about itself.
        case "$name" in
          crash-capture-* | agent-run) continue ;;
        esac

        now=$EPOCHSECONDS
        if ((now - ''${last_notified[$name]:-0} < dedupe)); then
          continue
        fi
        last_notified[$name]=$now

        crash-capture-notify "$name" "$pid" "$exe" "$signal" &
      done < <(journalctl -f -n 0 -o json "MESSAGE_ID=${coredumpMessageId}" 2>/dev/null)
    '';
  };
in
  # Nothing to offer without an agent to hand the crash to. mkIf also keeps a
  # null `launcher` from reaching the notifier's runtimeInputs.
  lib.mkIf hasAgent {
    systemd.user.services.crash-capture = {
      Unit = {
        Description = "Announce process crashes and offer an AI diagnosis";
        # Needs the session bus to notify, and a compositor to open a terminal on.
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = lib.getExe watcher;
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  }
