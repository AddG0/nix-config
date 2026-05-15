# Personal-flavor PiP styling overrides. The mechanics (toggle script,
# suppress_event for autoplay-next, no_initial_focus) live in common/pip.nix —
# this file only tunes the visual placement and sizing to match the
# macOS-leaning theme defined in ./visuals.nix.
_: {
  modules.hyprland.pip = {
    # Keep the common default 960x540 — the macOS-leaning 480x270 was too
    # small for actually watching video alongside other work.
    # Slightly tighter than the 20px default; matches the spacing visual
    # density used elsewhere (gaps_out = 8, hairline border).
    margin = 16;
    # Force size to 960x540 regardless of source video aspect ratio.
    # Non-16:9 content (vertical, 2.39:1, etc.) will letterbox/pillarbox
    # inside the window, but the window itself stays at a predictable size
    # and position.
    respectSourceSize = false;
    # forceOpaque stays on by default — video looks wrong translucent.
  };
}
