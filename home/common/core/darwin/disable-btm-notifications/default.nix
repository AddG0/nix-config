{
  lib,
  pkgs,
  ...
}: {
  # Every nix-darwin rebuild reloads its LaunchDaemons, and macOS posts a
  # "Background Items Added" notification (shown as "sh", since the daemons exec
  # via /bin/sh). Silence it by clearing the "Allow Notifications" bit (1 << 25)
  # on the Background Task Management agent's com.apple.ncprefs entry. There is
  # no declarative/MDM-free API for this, so we edit the pref directly and
  # reassert it each activation in case macOS re-enables it.
  home.activation.disableBTMNotifications = lib.hm.dag.entryAfter ["writeBoundary"] ''
    work="$(${pkgs.coreutils}/bin/mktemp)"
    if /usr/bin/defaults export com.apple.ncprefs "$work" 2>/dev/null \
      && ${pkgs.python3}/bin/python3 ${./clear-btm-notification-flag.py} "$work"; then
      run /usr/bin/defaults import com.apple.ncprefs "$work"
      run /usr/bin/killall usernoted 2>/dev/null || true
    fi
    ${pkgs.coreutils}/bin/rm -f "$work"
  '';
}
