# Pause nix binary-cache uploads while a game is running.
#
# The queued-build-hook daemon yields CPU/IO but not bandwidth, so an in-flight
# `nix copy` still lags a game on a thin uplink. This user service watches
# GameMode's ClientCount on the session bus (same signal as the safeeyes
# game-guard) and drives the daemon's control socket — pause on game start
# (cancelling any in-flight upload), resume on game end.
#
# Import only where the cache daemon AND gamemode are present; each gamer runs
# their own copy, all sharing the gamemode-owned control socket (see
# hosts/common/optional/nix-cache.nix).
{
  inputs,
  pkgs,
  lib,
  ...
}: let
  # Must match services.queued-build-hook.controlSocketPath in nix-cache.nix.
  # Not read from osConfig: home here builds standalone (osConfig = null in
  # home/flake-module.nix), so this literal is the single source of truth.
  controlSocket = "/var/lib/nix/queued-build-hook-control.sock";
  qbh = inputs.queued-build-hook.packages.${pkgs.stdenv.hostPlatform.system}.default;

  app = pkgs.writeShellApplication {
    name = "queued-build-cache-game-pause";
    runtimeInputs = [pkgs.glib qbh];
    text = ''
      socket="${controlSocket}"

      game_active() {
        local out
        out=$(gdbus call --session \
          --dest com.feralinteractive.GameMode \
          --object-path /com/feralinteractive/GameMode \
          --method org.freedesktop.DBus.Properties.Get \
          com.feralinteractive.GameMode ClientCount 2>/dev/null) || return 1
        # gdbus prints the variant between angle brackets, e.g. "(<2>,)".
        [[ "$out" =~ \<([0-9]+)\> ]] && [ "''${BASH_REMATCH[1]}" -gt 0 ]
      }

      # Only act on transitions — pause/resume are idempotent daemon-side, but
      # this keeps us from re-issuing (and re-logging) on every dbus event.
      last=""
      reconcile() {
        local want
        if game_active; then want=paused; else want=running; fi
        if [ "$want" = "$last" ]; then return 0; fi
        last="$want"
        if [ "$want" = paused ]; then
          if queued-build-hook pause --socket "$socket"; then
            echo "game active — paused cache uploads"
          else
            echo "warning: failed to pause cache uploads" >&2
          fi
        else
          if queued-build-hook resume --socket "$socket"; then
            echo "no game running — resumed cache uploads"
          else
            echo "warning: failed to resume cache uploads" >&2
          fi
        fi
      }

      # Reconcile whatever is already true at startup, then wake only on
      # ClientCount PropertiesChanged (filtered at C speed) — otherwise idle.
      reconcile
      gdbus monitor --session \
        --dest com.feralinteractive.GameMode \
        --object-path /com/feralinteractive/GameMode 2>/dev/null \
        | grep --line-buffered -E 'PropertiesChanged.*ClientCount' \
        | while IFS= read -r _; do reconcile; done
    '';
  };
in {
  systemd.user.services.queued-build-cache-game-pause = {
    Unit = {
      Description = "Pause nix binary-cache uploads while a game is running";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      Type = "simple";
      ExecStart = lib.getExe app;
      # Never leave uploads parked after logout/crash. Bounded by `timeout` so a
      # daemon that's already gone at shutdown can't stall session teardown on
      # the client's connect-retry.
      ExecStopPost = "${pkgs.coreutils}/bin/timeout 8 ${qbh}/bin/queued-build-hook resume --socket ${controlSocket}";
      # "always", not "on-failure": a session-bus hiccup can end `gdbus monitor`
      # with exit 0, which on-failure would treat as done — silently killing game
      # detection for the rest of the session.
      Restart = "always";
      RestartSec = 5;
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
