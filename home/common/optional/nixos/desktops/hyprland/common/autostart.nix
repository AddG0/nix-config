{pkgs, ...}: let
  systemctl = "${pkgs.systemd}/bin/systemctl";
  # Restart any XDG autostart apps (configured via xdg.autostart.entries) that
  # exited. Hyprland's reload doesn't normally re-fire systemd user services,
  # so if Hyprland boots into its recovery config and the user then reloads,
  # the autostart apps stay dead. `systemctl start --no-block` is a no-op for
  # services already active, so healthy reloads don't kill or respawn them.
  relaunch = pkgs.writeShellScript "hyprland-autostart-relaunch" ''
    set -eu
    ${systemctl} --user show xdg-desktop-autostart.target -p Wants --value 2>/dev/null \
      | tr ' ' '\n' \
      | ${pkgs.gnugrep}/bin/grep -E '^app-.*@autostart\.service$' \
      | while IFS= read -r unit; do
          ${systemctl} --user reset-failed "$unit" 2>/dev/null || true
          ${systemctl} --user start --no-block "$unit" 2>/dev/null || true
        done
  '';
in {
  wayland.windowManager.hyprland.settings.exec = ["${relaunch}"];
}
