_: {
  programs.steam.gamescopeSession = {
    enable = true;
    args = [
      # --rt is a no-op while gamescope.capSysNice is false (no cap_sys_nice
      # to grant realtime) — kept for when that's resolved without breaking
      # Steam's bwrap. See capSysNice below.
      "--rt" # Use realtime scheduling
      "--expose-wayland" # Expose Wayland socket
      # Disabled to fix artifacting in steam gamescope
      # "--adaptive-sync" # Enable VRR/adaptive sync
      "--force-grab-cursor" # Better mouse capture for games
    ];
  };

  # gamescope launch args set dynamically in home/<user>/common/optional/gaming
  programs.gamescope = {
    enable = true;
    # Disabled so the Steam gamescope session launches: capSysNice puts a
    # cap_sys_nice wrapper on the `gamescope` in PATH, and the session-launched
    # gamescope pushes that cap into its children's ambient set — Steam's bwrap
    # sandbox inherits it and refuses to start, killing the session. Per-game
    # nested gamescope uses the uncapped store binary, so it's unaffected.
    # https://github.com/NixOS/nixpkgs/issues/312195
    capSysNice = false;
  };
}
