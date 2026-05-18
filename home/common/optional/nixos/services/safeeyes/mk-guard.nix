# Shared scaffolding for Safe Eyes guards.
#
# A guard is a small daemon that disables Safe Eyes while some condition holds
# (e.g. a webcam is open, a game is running). Each guard supplies:
#   - name           — kebab-case identifier; produces systemd unit
#                      safeeyes-<name>-guard and flag file <name>-guard.
#   - description    — shown in `systemctl status`.
#   - runtimeInputs  — extra packages for the shell app (beyond the shared
#                      coreutils/gnugrep/safeeyes baseline).
#   - conditionFn    — shell text defining `condition_active()`, returning 0
#                      when Safe Eyes should be disabled.
#   - eventLoop      — shell text that calls `reconcile` on relevant events.
#                      Should block (inotify, gdbus monitor, …) to avoid
#                      polling. May reference helpers from the shared header.
#
# Coordination protocol — all state lives under $XDG_RUNTIME_DIR/safeeyes-guards/:
#   flags/<name>-guard   — set while that guard's condition is active.
#   disabled-by-guards   — sentinel: present iff the guards collectively
#                          initiated the --disable. Lets us distinguish "we
#                          turned it off" from "the user turned it off" so a
#                          manual --disable isn't undone when guards release.
#
# Invariants the protocol maintains:
#   - While any flag is set, Safe Eyes is off (we --disable on first activation).
#   - When the last flag clears, we --enable iff the sentinel is present.
#   - A user's manual --disable taken outside a guard window survives across
#     guard activations and deactivations (the sentinel won't be set, so we
#     never issue a --enable to clobber it).
#
# Known limitation:
#   - A user's manual --disable taken DURING a guard window (i.e. while the
#     sentinel is already set) is indistinguishable from "user re-affirmed our
#     disable" and will be undone when the last guard's condition clears. The
#     `safeeyes` CLI doesn't expose intent, so we can't tell the two apart.
#     Workaround: --enable then --disable to claim ownership outside any
#     guard's window, or stop the guard's user service.
#
# Live-watch the protocol:
#   watch -n 0.5 'ls /run/user/$UID/safeeyes-guards/ /run/user/$UID/safeeyes-guards/flags/ 2>/dev/null; safeeyes --status'
{
  lib,
  pkgs,
}: {
  mkGuard = {
    name,
    description,
    conditionFn,
    eventLoop,
    runtimeInputs ? [],
  }: let
    app = pkgs.writeShellApplication {
      name = "safeeyes-${name}-guard";
      runtimeInputs = with pkgs; [coreutils gnugrep safeeyes] ++ runtimeInputs;
      text = ''
        set -u

        guard_name="${name}-guard"
        state_dir="''${XDG_RUNTIME_DIR:-/tmp}/safeeyes-guards"
        flags_dir="$state_dir/flags"
        sentinel="$state_dir/disabled-by-guards"
        my_flag="$flags_dir/$guard_name"
        mkdir -p "$flags_dir"

        safeeyes_disabled() {
          safeeyes --status 2>/dev/null | grep -qi '^Disabled'
        }

        any_flag() {
          shopt -s nullglob
          local flags=("$flags_dir"/*)
          shopt -u nullglob
          [ "''${#flags[@]}" -gt 0 ]
        }

        mark_active() {
          # Note our condition is active. Only initiate --disable (and claim
          # collective ownership via the sentinel) if Safe Eyes is currently
          # ON — otherwise something else (user, other guard) already owns the
          # disabled state and we leave the sentinel alone.
          touch "$my_flag"
          if ! safeeyes_disabled; then
            safeeyes --disable >/dev/null 2>&1 || true
            touch "$sentinel"
          fi
        }

        mark_inactive() {
          # Note our condition is no longer active. Re-enable only if no other
          # guard still needs it off AND the sentinel says the guard system
          # was the one that disabled it. If the sentinel is absent, a user
          # disabled Safe Eyes manually and we must not undo that.
          [ ! -e "$my_flag" ] && return 0
          rm -f "$my_flag"
          any_flag && return 0
          if [ -e "$sentinel" ]; then
            rm -f "$sentinel"
            safeeyes --enable >/dev/null 2>&1 || true
          fi
        }

        reconcile() {
          if condition_active; then
            mark_active
          else
            mark_inactive
          fi
        }

        trap mark_inactive EXIT INT TERM

        ${conditionFn}

        ${eventLoop}
      '';
    };
  in {
    home.packages = [app];

    systemd.user.services."safeeyes-${name}-guard" = {
      Unit = {
        Description = description;
        After = ["graphical-session.target" "safeeyes.service"];
        Wants = ["safeeyes.service"];
        PartOf = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = lib.getExe app;
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
