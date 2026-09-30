{
  lib,
  pkgs,
  ...
}:
(import ./mk-guard.nix {inherit lib pkgs;}).mkGuard {
  name = "screenshare";
  description = "Disable Safe Eyes while a screen is being shared via pipewire";
  runtimeInputs = with pkgs; [pipewire jq gnugrep];

  # A screencast through xdg-desktop-portal creates a pipewire client node
  # with media.class = "Stream/Input/Video" that consumes from the portal's
  # Video/Source. gpu-screen-recorder runs persistently on this host as a
  # replay-buffer client and shows up under the same class, so we exclude it
  # by node.name / application.name. Anything else of that class — Discord,
  # Slack, Zoom, browser tabs, OBS in portal mode — counts as active sharing.
  conditionFn = ''
    condition_active() {
      local count
      count=$(pw-dump 2>/dev/null \
        | jq '[
            .[]
            | select(.info.props["media.class"]? == "Stream/Input/Video")
            | select(
                ((.info.props["node.name"] // .info.props["application.name"] // "")
                  | test("gpu-screen-recorder|^gsr-"; "i")) | not
              )
          ] | length' 2>/dev/null) || return 1
      [ -n "$count" ] && [ "$count" -gt 0 ]
    }
  '';

  # pw-mon is chatty (per-frame parameter updates push thousands of lines/sec
  # during active shares), so we filter at C speed via grep for the only lines
  # that matter — object add/remove markers — before reaching bash, then
  # coalesce so a burst of add/remove events at share start/stop only costs one
  # reconcile.
  eventLoop = ''
    reconcile

    coalesce_reconcile 3 9 < <(pw-mon 2>/dev/null | grep --line-buffered -E '^(added|removed):' || true)
  '';
}
