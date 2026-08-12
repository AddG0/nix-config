{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.wayland.windowManager.hyprland.enable (
  (import ./mk-guard.nix {inherit lib pkgs;}).mkGuard {
    name = "hyprland-game";
    description = "Disable Safe Eyes while a window tagged `game` is open";
    runtimeInputs = [config.wayland.windowManager.hyprland.package pkgs.jq pkgs.socat];

    # Complements the gamemode guard: catches games that never call
    # gamemode_request_start, e.g. a Prism instance with Feral GameMode off.
    conditionFn = ''
      condition_active() {
        local count
        # windowrule-applied tags report with a `*` suffix; hand-set ones don't.
        count=$(hyprctl clients -j 2>/dev/null \
          | jq '[.[] | select(.tags | any(rtrimstr("*") == "game"))] | length' 2>/dev/null) || return 1
        [ -n "$count" ] && [ "$count" -gt 0 ]
      }
    '';

    # windowtitle fires several times a second off any terminal with a live
    # title, so wake only on the window lifecycle. Hyprland applies windowrules
    # during map, so the tag is already set by the time openwindow arrives.
    eventLoop = ''
      reconcile

      coalesce_reconcile 1 5 < <(socat -u \
        UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - \
        | grep --line-buffered -E '^(openwindow|closewindow)>>' || true)
    '';
  }
)
