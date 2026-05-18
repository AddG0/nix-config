{
  lib,
  pkgs,
  ...
}:
(import ./mk-guard.nix {inherit lib pkgs;}).mkGuard {
  name = "game";
  description = "Disable Safe Eyes while a game is registered with gamemoded";
  runtimeInputs = [pkgs.glib];

  conditionFn = ''
    condition_active() {
      local out
      out=$(gdbus call --session \
        --dest com.feralinteractive.GameMode \
        --object-path /com/feralinteractive/GameMode \
        --method org.freedesktop.DBus.Properties.Get \
        com.feralinteractive.GameMode ClientCount 2>/dev/null) || return 1

      # gdbus prints the variant value between angle brackets, e.g. "(<2>,)".
      if [[ "$out" =~ \<([0-9]+)\> ]]; then
        [ "''${BASH_REMATCH[1]}" -gt 0 ]
      else
        return 1
      fi
    }
  '';

  # Block on D-Bus property changes. PropertiesChanged on ClientCount triggers
  # a re-check; otherwise the process is idle (no polling, no wakeups).
  eventLoop = ''
    # Handle a game that's already running at service start.
    reconcile

    while IFS= read -r line; do
      case "$line" in
        *PropertiesChanged*ClientCount*)
          reconcile
          ;;
      esac
    done < <(gdbus monitor --session \
      --dest com.feralinteractive.GameMode \
      --object-path /com/feralinteractive/GameMode)
  '';
}
