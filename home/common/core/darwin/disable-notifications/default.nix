{
  lib,
  pkgs,
  ...
}: let
  # An app only gets an ncprefs entry after its first notification; until then there is nothing to clear.
  silenced = [
    # "Background Items Added" (shown as "sh") on every nix-darwin rebuild, since its LaunchDaemons exec via /bin/sh.
    "com.apple.BTMNotificationAgent"
    "com.apple.tips"
  ];
in {
  # Clears the "Allow Notifications" bit (1 << 25) on each app's com.apple.ncprefs
  # entry. There is no declarative/MDM-free API for this, so we edit the pref
  # directly and reassert it each activation in case macOS re-enables it.
  home.activation.disableNotifications = lib.hm.dag.entryAfter ["writeBoundary"] ''
    work="$(${pkgs.coreutils}/bin/mktemp)"
    if /usr/bin/defaults export com.apple.ncprefs "$work" 2>/dev/null \
      && ${pkgs.python3}/bin/python3 ${./clear-notification-flag.py} "$work" ${lib.escapeShellArgs silenced}; then
      run /usr/bin/defaults import com.apple.ncprefs "$work"
      run /usr/bin/killall usernoted 2>/dev/null || true
    fi
    ${pkgs.coreutils}/bin/rm -f "$work"
  '';
}
