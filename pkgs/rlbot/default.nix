# Server plus GUI under one command. Upstream's Windows launcher keeps the
# server alive as a background service; on Linux nothing does.
{
  lib,
  writeShellApplication,
  systemd,
  coreutils,
  makeDesktopItem,
  symlinkJoin,
  fetchurl,
  rlbot-server,
  rlbot-gui,
}: let
  launcher = writeShellApplication {
    name = "rlbot";
    runtimeInputs = [rlbot-server rlbot-gui systemd coreutils];
    text = ''
      port="''${RLBOT_SERVER_PORT:-23234}"

      # The unit restarts the server after each match, which is why the GUI can
      # outlive it. Only stop what we started - a second rlbot must not pull the
      # server out from under the first.
      if systemctl --user is-active --quiet rlbot-server; then
        echo "rlbot: rlbot-server.service already running"
      elif systemctl --user start rlbot-server 2>/dev/null; then
        trap 'systemctl --user stop rlbot-server' EXIT
        echo "rlbot: started rlbot-server.service"
      elif (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
        echo "rlbot: reusing RLBotServer already on port $port"
      else
        log="''${XDG_STATE_HOME:-$HOME/.local/state}/rlbot/server.log"
        mkdir -p "$(dirname "$log")"
        RLBotServer "$port" >>"$log" 2>&1 &
        server_pid=$!
        trap 'kill "$server_pid" 2>/dev/null || true' EXIT
        echo "rlbot: started RLBotServer (pid $server_pid, log $log)"
      fi

      # systemctl start returns once the process forks, not once it has bound.
      waited=0
      while [ "$waited" -lt 50 ]; do
        if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then break; fi
        sleep 0.1
        waited=$((waited + 1))
      done

      rlbotgui "$@"
    '';
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/RLBot/gui/${rlbot-gui.version}/build/appicon.png";
    hash = "sha256-MoW7GmVUtVuoeMk6Rrh+X5Eul46LXt9f4QSO/RATjZw=";
  };

  desktopItem = makeDesktopItem {
    name = "rlbot";
    exec = "rlbot";
    icon = "rlbot";
    desktopName = "RLBot";
    genericName = "Rocket League Bot Framework";
    comment = "Run custom Rocket League bots offline";
    categories = ["Game"];
    keywords = ["rocket" "league" "bot" "rlbot"];
    startupWMClass = "rlbotgui";
  };
in
  symlinkJoin {
    name = "rlbot";
    paths = [launcher desktopItem];

    postBuild = ''
      install -Dm644 ${icon} "$out/share/pixmaps/rlbot.png"
    '';

    meta = {
      description = "RLBot v5: RLBotServer plus the GUI, under one command";
      homepage = "https://rlbot.org/v5/";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "rlbot";
    };
  }
