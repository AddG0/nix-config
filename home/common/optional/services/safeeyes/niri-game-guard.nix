{
  config,
  lib,
  options,
  osConfig ? null,
  pkgs,
  ...
}: {
  # gaming.windowClasses defines what a game is; a host without the gaming modules has nothing to guard.
  # niri's options exist on every NixOS host, so ask the system whether it runs niri.
  config = lib.optionalAttrs (options ? gaming) (lib.mkIf (osConfig.programs.niri.enable or false) (lib.mkMerge [
    # mk-guard binds to graphical-session.target, which every desktop starts.
    {
      systemd.user.services.safeeyes-niri-game-guard = {
        Install.WantedBy = lib.mkForce ["niri.service"];
        Unit.PartOf = lib.mkForce ["niri.service"];
      };
    }
    ((import ./mk-guard.nix {inherit lib pkgs;}).mkGuard {
      name = "niri-game";
      description = "Disable Safe Eyes while a game window is open";
      runtimeInputs = [config.programs.niri.package pkgs.jq];

      conditionFn = ''
        condition_active() {
          local count
          count=$(niri msg -j windows 2>/dev/null \
            | jq --arg game ${lib.escapeShellArg (lib.concatMapStringsSep "|" (class: "(${class})") config.gaming.windowClasses)} '[.[] | select(.app_id // "" | test($game))] | length' 2>/dev/null) || return 1
          [ -n "$count" ] && [ "$count" -gt 0 ]
        }
      '';

      # Title changes also arrive as WindowOpenedOrChanged, so the debounce does the work.
      eventLoop = ''
        reconcile

        coalesce_reconcile 1 5 < <(niri msg -j event-stream \
          | grep --line-buffered -E '^\{"Window(OpenedOrChanged|Closed|sChanged)"' || true)
      '';
    })
  ]));
}
