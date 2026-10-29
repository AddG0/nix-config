# Session entries as display managers read them, and start-session run against rendered entries.
{
  pkgs,
  lib,
  harness,
  ...
}: let
  render = import ../_render.nix {inherit lib pkgs;};

  # Records its arguments, standing in for a compositor.
  fakeDesktop = pkgs.writeShellScript "fake-desktop" ''
    printf '%s\n' "$@" > "$OUT_LOG"
  '';

  desktop = {
    sessionName = "hyprland-uwsm";
    displayName = "Hyprland";
    desktopNames = ["Hyprland"];
    command = "${fakeDesktop} start hyprland.desktop";
    noDisplay = false;
    desktop = true;
  };
  gaming = {
    sessionName = "gaming-mode";
    displayName = "Gaming Mode";
    desktopNames = [];
    command = "gaming-dispatcher gamescope";
    noDisplay = false;
    desktop = false;
  };
  compositor = {
    sessionName = "hyprland";
    displayName = "Hyprland";
    desktopNames = ["Hyprland"];
    command = "start-hyprland";
    noDisplay = true;
    desktop = false;
  };

  wrapped = render.entry "session-dispatcher desktop" desktop;
  unwrapped = render.entry null desktop;
  gamingWithWrapper = render.entry "session-dispatcher desktop" gaming;
  hiddenCompositor = render.entry "session-dispatcher desktop" compositor;

  # A desktop action's Exec= after the session's own, as upstream entries may carry.
  withAction = pkgs.writeTextDir "share/wayland-sessions/with-action.desktop" ''
    [Desktop Entry]
    Name=With action
    Exec=${fakeDesktop} main
    Type=Application

    [Desktop Action other]
    Exec=${fakeDesktop} action
  '';

  sessions = pkgs.symlinkJoin {
    name = "sessions";
    paths = [unwrapped withAction];
  };
  startSession = lib.getExe (render.startSession "${sessions}/share/wayland-sessions");
  entryOf = pkg: key: "${pkg}/share/wayland-sessions/${key}.desktop";
in
  harness.check "desktop-sessions" ''
    ${(harness.paths.content "a wrapped desktop runs through the wrapper and keeps its desktop names" (entryOf wrapped "hyprland-uwsm") ''
      [Desktop Entry]
      Name=Hyprland
      Exec=session-dispatcher desktop ${fakeDesktop} start hyprland.desktop
      Type=Application
      DesktopNames=Hyprland'')}

    ${harness.paths.contains "without a wrapper a desktop runs its own command" (entryOf unwrapped "hyprland-uwsm") [
      "Exec=${fakeDesktop} start hyprland.desktop\n"
    ]}

    ${(harness.paths.content "a session that is not a desktop ignores the wrapper" (entryOf gamingWithWrapper "gaming-mode") ''
      [Desktop Entry]
      Name=Gaming Mode
      Exec=gaming-dispatcher gamescope
      Type=Application'')}

    ${(harness.paths.content "a session left out of greeters is marked NoDisplay, not Hidden, and is not wrapped" (entryOf hiddenCompositor "hyprland") ''
      [Desktop Entry]
      Name=Hyprland
      Exec=start-hyprland
      Type=Application
      DesktopNames=Hyprland
      NoDisplay=true'')}

    ${harness.values {
      "test an entry provides the session named by its session name" = {
        expr = wrapped.providedSessions;
        expected = ["hyprland-uwsm"];
      };
    }}

    export OUT_LOG=$PWD/args.log
    ${startSession} hyprland-uwsm
    printf 'start\nhyprland.desktop\n' | diff -u - "$OUT_LOG" \
      || { echo "FAIL start-session runs the named session's Exec= with its arguments" >&2; exit 1; }

    ${startSession} with-action
    printf 'main\n' | diff -u - "$OUT_LOG" \
      || { echo "FAIL start-session runs only the entry's first Exec=, not a desktop action's" >&2; exit 1; }

    if ${startSession} niri 2>err.log; then
      echo "FAIL start-session refuses a session with no entry: it exited 0" >&2; exit 1
    fi
    grep -q "no session 'niri' in ${sessions}/share/wayland-sessions" err.log \
      || { cat err.log >&2; echo "FAIL start-session names the missing session and where it looked" >&2; exit 1; }
  ''
