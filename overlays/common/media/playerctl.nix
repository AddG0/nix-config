# playerctld (upstream dead since 2.4.1) warns whenever a player lacks the optional TrackList/Playlists interfaces.
_: _final: prev: {
  playerctl = prev.playerctl.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./playerctld-optional-interfaces.patch];
  });
}
