# greetd-native desktop <-> Steam gamescope switching (SteamOS's SDDM swap has
# no greetd backend). A dispatcher runs one session at a time; a marker file
# picks the next after the current exits (none -> greeter). Desktop half is
# services.greetd.sessionCommand, not a hardcoded compositor.
#   desktop->gaming: "Gaming Mode" app launcher writes `gamescope`, stops the desktop
#   gaming->desktop: Steam "Switch to Desktop" -> steamos-session-select
#   gaming->greeter: quit Steam, no marker
{
  config,
  lib,
  pkgs,
  ...
}: let
  steamBin = "${config.programs.steam.package}/bin/steam";
  desktopCmd = config.services.greetd.sessionCommand;

  # gamescope spawns `mangoapp` (the --mangoapp QAM perf overlay) from PATH;
  # wrap it so mangohud is found without leaking it into the global env or
  # trusting the session's PATH. pkgs.gamescope is uncapped (no cap_sys_nice).
  gamescopeWithMango = pkgs.symlinkJoin {
    name = "gamescope-mangoapp";
    paths = [pkgs.gamescope];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/gamescope --prefix PATH : ${pkgs.mangohud}/bin";
  };

  # NOT full Deck mode: SteamDeck=1/-steamdeck route "Switch to Desktop" through
  # steamos-manager (needs jovian.steam) and hang, instead of exec'ing
  # /usr/bin/steamos-session-select.
  gamescopeCmd = "${gamescopeWithMango}/bin/gamescope --steam --rt --expose-wayland --force-grab-cursor --mangoapp -- ${steamBin} -gamepadui -pipewire-dmabuf";

  marker = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gaming-session-next"'';

  dispatcher = pkgs.writeShellScript "session-dispatcher" ''
    set -u
    current="''${1:-desktop}"
    while :; do
      rm -f ${marker}
      case "$current" in
        gamescope) ${gamescopeCmd} || true ;;
        *) ${desktopCmd} || true ;;
      esac
      case "$(cat ${marker} 2>/dev/null || true)" in
        gamescope) current=gamescope ;;
        desktop) current=desktop ;;
        *) break ;;
      esac
    done
  '';

  # Steam's "Switch to Desktop" execs /usr/bin/steamos-session-select.
  sessionSelect = pkgs.writeShellScriptBin "steamos-session-select" ''
    echo desktop > ${marker}
    exec ${steamBin} -shutdown
  '';

  # App-launcher counterpart to Steam's "Switch to Desktop": `uwsm stop` ends the
  # desktop (paired with the `uwsm start` in sessionCommand) so the dispatcher
  # loops into gamescope.
  enterGaming = pkgs.writeShellScript "enter-gaming-mode" ''
    echo gamescope > ${marker}
    exec ${lib.getExe pkgs.uwsm} stop
  '';
  enterGamingApp = pkgs.makeDesktopItem {
    name = "gaming-mode";
    desktopName = "Gaming Mode";
    comment = "Switch to the Steam gamescope session";
    icon = "steam";
    exec = "${enterGaming}";
    categories = ["Game"];
  };

  gamingSession =
    (pkgs.writeTextDir "share/wayland-sessions/gaming-mode.desktop" ''
      [Desktop Entry]
      Name=Gaming Mode
      Exec=${dispatcher} gamescope
      Type=Application
    '')
    .overrideAttrs (_: {passthru.providedSessions = ["gaming-mode"];});
in
  lib.mkIf config.services.greetd.enable {
    services.displayManager.sessionPackages = [gamingSession];
    environment.systemPackages = [enterGamingApp];

    # Autologin via the dispatcher too. Override the command, not sessionCommand,
    # or desktopCmd's read of it cycles. mkIf must guard the whole table — a
    # leaf-only mkIf leaves an empty [initial_session] that greetd rejects.
    services.greetd.settings.initial_session = lib.mkIf config.services.greetd.autoLogin.enable {
      command = lib.mkForce "${dispatcher} desktop";
    };

    systemd.tmpfiles.rules = [
      "L+ /usr/bin/steamos-session-select - - - - ${lib.getExe sessionSelect}"
    ];
  }
