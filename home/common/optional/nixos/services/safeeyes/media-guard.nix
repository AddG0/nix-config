{
  lib,
  pkgs,
  ...
}:
(import ./mk-guard.nix {inherit lib pkgs;}).mkGuard {
  name = "media";
  description = "Disable Safe Eyes while a browser is playing media (heuristic: video)";
  runtimeInputs = with pkgs; [glib dbus];

  # MPRIS players expose `org.mpris.MediaPlayer2.<player>` with a Player
  # interface and a `PlaybackStatus` property. We restrict to browser players
  # only (firefox, chromium-derived, etc.) — this catches video viewing
  # (YouTube, etc.) without disabling Safe Eyes for music apps like Spotify.
  # Caveat: browser audio (SoundCloud, internet radio) will also trigger.
  conditionFn = ''
    list_mpris_names() {
      # Pull org.mpris.MediaPlayer2.* names out of the bus's ListNames result.
      gdbus call --session --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.ListNames 2>/dev/null \
        | grep -oE 'org\.mpris\.MediaPlayer2\.[A-Za-z0-9._-]+'
    }

    condition_active() {
      local name name_tail player_base state
      while IFS= read -r name; do
        name_tail="''${name#org.mpris.MediaPlayer2.}"
        # First label after the namespace identifies the player; Firefox uses
        # "firefox.instance_N", chromium-based uses "chromium.instance_N", etc.
        player_base="''${name_tail%%.*}"
        case "$player_base" in
          firefox|chromium|chrome|brave|vivaldi|librewolf|waterfox) ;;
          *) continue ;;
        esac
        state=$(gdbus call --session --dest "$name" \
          --object-path /org/mpris/MediaPlayer2 \
          --method org.freedesktop.DBus.Properties.Get \
          org.mpris.MediaPlayer2.Player PlaybackStatus 2>/dev/null) || continue
        [[ "$state" == *Playing* ]] && return 0
      done < <(list_mpris_names)
      return 1
    }
  '';

  # Two D-Bus match rules, both narrow enough that we only wake on relevant
  # events: PlaybackStatus property changes on MPRIS Player, and player bus
  # names appearing/disappearing on the MPRIS namespace.
  eventLoop = ''
    reconcile

    while IFS= read -r line; do
      case "$line" in
        *PropertiesChanged*|*NameOwnerChanged*)
          reconcile
          ;;
      esac
    done < <(dbus-monitor --session \
      "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'" \
      "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0namespace='org.mpris.MediaPlayer2'" \
      2>/dev/null || true)
  '';
}
