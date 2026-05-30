# Recovery handling for Hyprland: when the compositor boots into its
# recovery config (because the real config was unreadable at startup),
# `hyprctl reload` doesn't fire `exec-once` items or restart graphical
# session services, and workspaces created during recovery stay on the
# wrong monitors. This module wires a single handler that detects the
# recovery scenario via Hyprland's own log file and runs all the
# concern-specific recovery actions once per affected instance.
#
# Architectural note: the handler is invoked from `extraConfig` (a plain
# string), not `settings.exec`. That avoids the same-attr recursion that
# would otherwise occur because we read `settings.workspace` to derive
# the workspace-pin dispatches.
{
  config,
  pkgs,
  lib,
  ...
}: let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  systemctl = "${pkgs.systemd}/bin/systemctl";

  # ── Action 1: restart systemd user services that died with the previous
  # compositor (walker, wpaperd, hypridle, app-*@autostart, etc.).
  # `start --no-block` is a no-op for already-active services, so this is
  # safe even if some survived.
  serviceRelaunch = pkgs.writeShellScript "hyprland-recovery-services" ''
    set -eu
    for target in graphical-session.target xdg-desktop-autostart.target; do
      ${systemctl} --user show "$target" -p Wants --value 2>/dev/null \
        | tr ' ' '\n' \
        | while IFS= read -r unit; do
            [ -n "$unit" ] || continue
            ${systemctl} --user reset-failed "$unit" 2>/dev/null || true
            ${systemctl} --user start --no-block "$unit" 2>/dev/null || true
          done
    done
  '';

  # ── Action 2: fire every `exec-once` entry from the now-loaded real
  # config. Hyprland's own exec-once dispatch ran once against the recovery
  # config (which had none), so the real-config entries never fired and
  # Hyprland's "one dispatch per instance" policy means they never will.
  execOnceRelaunch = pkgs.writeShellScript "hyprland-recovery-exec-once" ''
    set -eu
    config="''${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
    [ -r "$config" ] || exit 0
    ${pkgs.gnused}/bin/sed -n 's/^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*//p' "$config" \
      | while IFS= read -r line; do
          [ -n "$line" ] || continue
          setsid sh -c "$line" >/dev/null 2>&1 &
        done
  '';

  # ── Action 3: re-pin workspaces to their declared monitor. The
  # `workspace = "N, monitor:M, …"` rule binds the monitor at workspace
  # CREATION time only, so workspaces created during recovery sit on the
  # wrong output until we dispatch them. `moveworkspacetomonitor` is a
  # no-op when the workspace is already on the target.
  trim = s: lib.removePrefix " " (lib.removeSuffix " " s);
  parsePin = wsString: let
    parts = lib.splitString "," wsString;
    workspace = trim (builtins.head parts);
    monitorPart =
      lib.findFirst
      (p: lib.hasPrefix "monitor:" (trim p))
      null
      (builtins.tail parts);
  in
    if monitorPart == null
    then null
    else {
      inherit workspace;
      monitor = lib.removePrefix "monitor:" (trim monitorPart);
    };
  workspaces = config.wayland.windowManager.hyprland.settings.workspace or [];
  pins = lib.filter (x: x != null) (map parsePin workspaces);
  workspaceRepin = pkgs.writeShellScript "hyprland-recovery-workspaces" ''
    set -eu
    ${lib.concatMapStringsSep "\n"
      (p: "${hyprctl} dispatch moveworkspacetomonitor ${p.workspace} ${p.monitor}")
      pins}
  '';

  # ── The handler. Runs only when this Hyprland instance booted into the
  # recovery config (evidence: "recoverycfg.conf" in its own log) AND we
  # haven't already run for this instance (evidence: marker file keyed on
  # $HYPRLAND_INSTANCE_SIGNATURE). Both checks are race-free reads of
  # already-written state, so no sleep/polling is needed.
  recoveryHandler = pkgs.writeShellScript "hyprland-recovery-handler" ''
    set -eu
    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    sig="''${HYPRLAND_INSTANCE_SIGNATURE:-unknown}"
    marker="$runtime_dir/hyprland-recovery-handled-$sig"
    log="$runtime_dir/hypr/$sig/hyprland.log"
    [ -e "$marker" ] && exit 0
    [ -r "$log" ] || exit 0
    ${pkgs.gnugrep}/bin/grep -qF "recoverycfg.conf" "$log" || exit 0
    # GC orphan markers from dead Hyprland instances before planting ours.
    for m in "$runtime_dir"/hyprland-recovery-handled-*; do
      [ -e "$m" ] || continue
      osig="''${m##*-handled-}"
      [ -d "$runtime_dir/hypr/$osig" ] || rm -f "$m"
    done
    ${serviceRelaunch} || true
    ${execOnceRelaunch} || true
    ${workspaceRepin} || true
    touch "$marker"
  '';
in {
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    exec = ${recoveryHandler}
  '';
}
