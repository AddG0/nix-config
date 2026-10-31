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

  # The plan for a host with these desktops beside a Gaming Mode session that is not one.
  planFor = desktopKeys: primarySession: let
    plan = render.plan {
      sessions = lib.genAttrs desktopKeys (_: {desktop = true;}) // {gaming-mode.desktop = false;};
      inherit primarySession;
    };
  in {inherit (plan) hasLauncher primaryDesktop loginSession;};

  # Records which desktop it was started as and the session variables it got.
  launchedDesktop = name: desktopNames: {
    sessionName = name;
    inherit desktopNames;
    command = "${pkgs.writeShellScript "launched-${name}" ''
      printf '%s %s %s\n' ${name} "''${XDG_CURRENT_DESKTOP:-}" "''${XDG_SESSION_DESKTOP:-}" > "$OUT_LOG"
    ''}";
  };
  launcher = lib.getExe (render.launcher {
    desktops = {
      plasma = launchedDesktop "plasma" ["KDE"];
      niri = launchedDesktop "niri" ["niri"];
    };
    fallback = "plasma";
  });
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
      "test one desktop gets no launcher and logs into the primary session" = {
        expr = planFor ["plasma"] "plasma";
        expected = {
          hasLauncher = false;
          primaryDesktop = "plasma";
          loginSession = "plasma";
        };
      };
      "test several desktops log into the launcher, falling back to the primary desktop" = {
        expr = planFor ["niri" "plasma"] "plasma";
        expected = {
          hasLauncher = true;
          primaryDesktop = "plasma";
          loginSession = "desktop";
        };
      };
      "test standalone Gaming Mode keeps autologin and falls back to the first desktop" = {
        expr = planFor ["niri" "plasma"] "gaming-mode";
        expected = {
          hasLauncher = true;
          primaryDesktop = "niri";
          loginSession = "gaming-mode";
        };
      };
      "test a null primary session still has a desktop to fall back to" = {
        expr = planFor ["niri" "plasma"] null;
        expected = {
          hasLauncher = true;
          primaryDesktop = "niri";
          loginSession = null;
        };
      };
      "test a host without desktops has nothing to fall back to" = {
        expr = planFor [] null;
        expected = {
          hasLauncher = false;
          primaryDesktop = null;
          loginSession = null;
        };
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

    export HOME=$PWD/home
    unset XDG_CONFIG_HOME
    choice=$HOME/.config/desktops/default-session
    mkdir -p "$(dirname "$choice")"

    printf 'niri\n' > "$choice"
    ${launcher} 2>err.log
    printf 'niri niri niri\n' | diff -u - "$OUT_LOG" \
      || { echo "FAIL the launcher starts the user's default desktop with its session variables" >&2; exit 1; }

    rm "$choice"
    ${launcher} 2>err.log
    printf 'plasma KDE plasma\n' | diff -u - "$OUT_LOG" \
      || { echo "FAIL the launcher falls back to the host's desktop when the user has no default" >&2; exit 1; }
    grep -q "no default session in $choice; starting plasma" err.log \
      || { cat err.log >&2; echo "FAIL the launcher says why it fell back on a missing file" >&2; exit 1; }

    : > "$choice"
    ${launcher} 2>err.log
    printf 'plasma KDE plasma\n' | diff -u - "$OUT_LOG" \
      || { echo "FAIL the launcher treats an empty default like a missing one" >&2; exit 1; }

    printf 'gnome\n' > "$choice"
    ${launcher} 2>err.log
    printf 'plasma KDE plasma\n' | diff -u - "$OUT_LOG" \
      || { echo "FAIL the launcher falls back when the default names no desktop on this host" >&2; exit 1; }
    grep -q "names 'gnome', not a desktop here (niri, plasma); starting plasma" err.log \
      || { cat err.log >&2; echo "FAIL the launcher names the unknown default and this host's desktops" >&2; exit 1; }
  ''
