_: {
  # gamescope session lives in gamescope-session.nix, not programs.steam.gamescopeSession.
  programs.gamescope = {
    enable = true;
    # Kept uncapped as the default; the session/per-game gamescope both use the
    # uncapped store binary, and a cap_sys_nice wrapper on PATH gamescope breaks
    # Steam's bwrap. https://github.com/NixOS/nixpkgs/issues/312195
    capSysNice = false;
  };
}
